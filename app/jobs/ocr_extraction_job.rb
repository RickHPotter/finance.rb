# frozen_string_literal: true

class OcrExtractionJob < ApplicationJob
  queue_as :default

  retry_on Ocr::TextExtractor::ExtractionTimeout, wait: 5.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(fiscal_receipt_draft_id)
    draft = FiscalReceiptDraft.find(fiscal_receipt_draft_id)
    return unless draft.processing?

    begin
      result = run_pipeline(draft)
      fiscal_draft = process_hybrid_lookup(result, draft)
      payload = fiscal_draft.as_json.merge(ocr_details: ocr_details(result))

      draft.update!(payload: payload, status: :ready, ocr_error: nil)
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
    source_path = download_source(draft)

    image_paths = Ocr::ImagePreprocessor.new(source_path).call
    ocr_output = Ocr::TextExtractor.new(image_paths).call
    Ocr::ReceiptParser.new(ocr_output).call
  ensure
    cleanup_temp_files(image_paths)
  end

  def download_source(draft)
    raise Ocr::ImagePreprocessor::UnsupportedFormat, I18n.t("ocr.errors.file_missing") unless draft.source.attached?

    tempfile = Tempfile.new([ "ocr_source", File.extname(draft.source.filename.to_s) ], binmode: true)
    draft.source.download { |chunk| tempfile.write(chunk) }
    tempfile.rewind
    tempfile.path
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

  def cleanup_temp_files(paths)
    Array(paths).each do |path|
      File.delete(path) if path && File.exist?(path)
    rescue StandardError
      # Best-effort cleanup
    end
  end
end
