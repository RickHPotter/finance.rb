# frozen_string_literal: true

class OcrExtractionJob < ApplicationJob
  queue_as :default

  retry_on Ocr::TextExtractor::ExtractionTimeout, wait: 5.seconds, attempts: 2 do |job, error|
    draft = FiscalReceiptDraft.find_by(id: job.arguments.first)
    if draft&.processing?
      draft.update!(status: :failed, ocr_error: error.message)
      job.send(:broadcast_draft_update, draft)
    end
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(fiscal_receipt_draft_id)
    draft = FiscalReceiptDraft.find(fiscal_receipt_draft_id)
    return unless draft.processing?

    begin
      result = run_pipeline(draft)
      fiscal_draft = process_hybrid_lookup(result, draft)
      payload = fiscal_draft.as_json.merge(ocr_details: ocr_details(result))
      if fiscal_draft.source != "ocr" && fiscal_draft.access_key.present?
        payload[:identity_token] = FiscalReceipts::IdentityToken.issue(user: draft.user, access_key: fiscal_draft.access_key)
      end

      draft.update!(payload: payload, status: :ready, ocr_error: nil)
    rescue Ocr::TextExtractor::ExtractionTimeout
      raise
    rescue Ocr::ImagePreprocessor::UnsupportedFormat,
           Ocr::TextExtractor::ExtractionError => e
      draft.update!(status: :failed, ocr_error: e.message)
    rescue StandardError => e
      Rails.logger.error("[OcrExtractionJob] Unexpected error for draft #{draft.id}: #{e.class}")
      draft.update!(status: :failed, ocr_error: I18n.t("ocr.errors.unexpected"))
    ensure
      broadcast_draft_update(draft) if draft.persisted? && !draft.processing?
    end
  end

  private

  def broadcast_draft_update(draft)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ draft.user, :fiscal_receipt_drafts ],
      target: "fiscal_receipt_draft_#{draft.id}",
      html: ApplicationController.render(
        Views::Transactions::FiscalReceiptDraftCard.new(draft:),
        layout: false
      )
    )
  rescue StandardError => e
    Rails.logger.warn("[OcrExtractionJob] Broadcast failed for draft #{draft.id}: #{e.class}")
  end

  def process_hybrid_lookup(result, draft)
    ocr_draft = result.to_fiscal_draft
    return ocr_draft unless result.access_key.present?

    access_key = FiscalReceipts::AccessKey.new(result.access_key)
    return ocr_draft unless access_key.valid?

    structured_draft = attempt_structured_lookup(access_key, draft)
    return ocr_draft unless structured_draft

    Ocr::SourceComparator.new(structured_draft:, ocr_draft: result).call
  end

  def attempt_structured_lookup(access_key, _draft)
    return unless access_key.state_code == "41"

    FiscalReceipts::ParanaLookup.new(access_key.value).call
  rescue StandardError => e
    Rails.logger.warn("[OcrExtractionJob] Structured lookup failed: #{e.class}")
    nil
  end

  def run_pipeline(draft)
    Dir.mktmpdir("ocr_#{draft.id}_") do |work_dir|
      source_path = download_source(draft, work_dir)
      image_paths = Ocr::ImagePreprocessor.new(source_path, output_dir: work_dir).call
      ocr_output = Ocr::TextExtractor.new(image_paths).call
      Ocr::ReceiptParser.new(ocr_output).call
    end
  end

  def download_source(draft, work_dir)
    raise Ocr::ImagePreprocessor::UnsupportedFormat, I18n.t("ocr.errors.file_missing") unless draft.source.attached?

    ext = File.extname(draft.source.filename.to_s)
    path = File.join(work_dir, "source#{ext}")
    File.open(path, "wb") do |file|
      draft.source.download { |chunk| file.write(chunk) }
    end
    path
  end

  def ocr_details(result)
    {
      engine: result.source_engine,
      processing_ms: result.processing_ms,
      field_confidences: result.field_confidences,
      items_missing: result.items_missing?,
      ocr_originals: result.items.filter_map { |item| item[:ocr_original] }
    }
  end
end
