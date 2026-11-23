# frozen_string_literal: true

class FiscalReceiptImportsController < ApplicationController
  def create
    file = params[:file]
    result = file.respond_to?(:tempfile) ? draft_from_file(file) : draft_from_source(params[:source])

    if result.is_a?(Hash) && result[:ocr_pending]
      create_ocr_draft(file)
      return
    end

    draft = result
    payload = draft.as_json.merge(identity_token: FiscalReceipts::IdentityToken.issue(user: current_user, access_key: draft.access_key))
    existing = FiscalDocumentLink.find_by(user: current_user, context: current_context, access_key: draft.access_key)
    render json: { draft: payload, duplicate_transaction: existing.present?, evidence_signed_ids: create_evidence_blobs }
  rescue FiscalReceipts::XmlParser::InvalidDocument, FiscalReceipts::ParanaLookup::Unavailable, FiscalReceipts::GoiasLookup::Unavailable,
         FiscalReceipts::SourceKey::InvalidSource, FiscalReceipts::PdfKeyExtractor::Unreadable => e
    render_error(e.message)
  end

  private

  def draft_from_file(file)
    raise FiscalReceipts::XmlParser::InvalidDocument, I18n.t("fiscal_import.messages.file_too_large") if file.size > 10.megabytes

    case File.extname(file.original_filename.to_s).downcase
    when ".xml" then FiscalReceipts::XmlParser.new(file.read).call
    when ".pdf" then draft_from_pdf(file)
    else draft_from_image(file)
    end
  end

  def draft_from_pdf(file)
    draft_from_source(FiscalReceipts::PdfKeyExtractor.new(file).call)
  rescue FiscalReceipts::PdfKeyExtractor::NoSelectableText
    { ocr_pending: true }
  end

  def draft_from_image(file)
    ext = File.extname(file.original_filename.to_s).downcase
    raise FiscalReceipts::XmlParser::InvalidDocument, I18n.t("fiscal_import.messages.upload_fiscal_file") unless ext.in?(%w[.jpg .jpeg .png .heic .heif .tiff .tif])

    { ocr_pending: true }
  end

  def create_ocr_draft(file)
    receipt_draft = current_user.fiscal_receipt_drafts.new(
      status: :processing,
      payload: {}
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: { custom: { receipt_upload_user_id: current_user.id.to_s } }
    )
    receipt_draft.source.attach(blob)

    if receipt_draft.save
      OcrExtractionJob.perform_later(receipt_draft.id)
      render json: { ocr_queued: true, draft_id: receipt_draft.id, status: "processing" }, status: :accepted
    else
      render json: { error: receipt_draft.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  def draft_from_source(source)
    normalized = FiscalReceipts::SourceKey.new(source).call
    if normalized.start_with?("https://#{FiscalReceipts::GoiasLookup::HOST}/")
      lookup = FiscalReceipts::GoiasLookup.new(normalized)
      draft = lookup.call
      @evidence_files = lookup.evidence_files
      return draft
    end
    key = FiscalReceipts::AccessKey.new(normalized)
    raise FiscalReceipts::SourceKey::InvalidSource, I18n.t("fiscal_import.messages.nfe_xml_required") if key.valid? && key.model == "55"

    if key.state_code == "52"
      raise FiscalReceipts::GoiasLookup::Unavailable,
            I18n.t("fiscal_import.messages.goias_key_challenge")
    end

    FiscalReceipts::ParanaLookup.new(normalized).call
  end

  def create_evidence_blobs
    Array(@evidence_files).map do |file|
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(file.fetch(:data)),
        filename: file.fetch(:filename),
        content_type: file.fetch(:content_type),
        metadata: { custom: { receipt_upload_user_id: current_user.id.to_s } }
      ).signed_id
    end
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
