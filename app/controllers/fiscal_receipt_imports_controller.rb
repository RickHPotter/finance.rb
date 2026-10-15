# frozen_string_literal: true

class FiscalReceiptImportsController < ApplicationController
  def create
    file = params[:file]
    draft = file.respond_to?(:tempfile) ? draft_from_file(file) : draft_from_source(params[:source])
    render json: { draft: draft.as_json, evidence_signed_ids: create_evidence_blobs }
  rescue FiscalReceipts::XmlParser::InvalidDocument, FiscalReceipts::ParanaLookup::Unavailable, FiscalReceipts::GoiasLookup::Unavailable,
         FiscalReceipts::SourceKey::InvalidSource, FiscalReceipts::PdfKeyExtractor::Unreadable => e
    render_error(e.message)
  end

  private

  def draft_from_file(file)
    raise FiscalReceipts::XmlParser::InvalidDocument, I18n.t("fiscal_import.messages.file_too_large") if file.size > 10.megabytes

    case File.extname(file.original_filename.to_s).downcase
    when ".xml" then FiscalReceipts::XmlParser.new(file.read).call
    when ".pdf" then draft_from_source(FiscalReceipts::PdfKeyExtractor.new(file).call)
    else raise FiscalReceipts::XmlParser::InvalidDocument, I18n.t("fiscal_import.messages.upload_fiscal_file")
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
    if FiscalReceipts::AccessKey.new(normalized).state_code == "52"
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
