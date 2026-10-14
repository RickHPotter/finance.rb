# frozen_string_literal: true

class FiscalReceiptImportsController < ApplicationController
  def create
    file = params[:file]
    draft = file.respond_to?(:tempfile) ? draft_from_file(file) : draft_from_source(params[:source])
    render json: { draft: draft.as_json }
  rescue FiscalReceipts::XmlParser::InvalidDocument, FiscalReceipts::ParanaLookup::Unavailable, FiscalReceipts::GoiasLookup::Unavailable,
         FiscalReceipts::SourceKey::InvalidSource, FiscalReceipts::PdfKeyExtractor::Unreadable => e
    render_error(e.message)
  end

  private

  def draft_from_file(file)
    raise FiscalReceipts::XmlParser::InvalidDocument, "The fiscal file must be 10 MB or smaller." if file.size > 10.megabytes

    case File.extname(file.original_filename.to_s).downcase
    when ".xml" then FiscalReceipts::XmlParser.new(file.read).call
    when ".pdf" then draft_from_source(FiscalReceipts::PdfKeyExtractor.new(file).call)
    else raise FiscalReceipts::XmlParser::InvalidDocument, "Upload a fiscal XML, PDF, or a readable QR image."
    end
  end

  def draft_from_source(source)
    normalized = FiscalReceipts::SourceKey.new(source).call
    return FiscalReceipts::GoiasLookup.new(normalized).call if normalized.start_with?("https://#{FiscalReceipts::GoiasLookup::HOST}/")
    if FiscalReceipts::AccessKey.new(normalized).state_code == "52"
      raise FiscalReceipts::GoiasLookup::Unavailable,
            "For Goiás, upload a cupom photo with a readable QR, paste its complete QR URL, or provide authorized XML. Key-only consultation requires a browser challenge."
    end

    FiscalReceipts::ParanaLookup.new(normalized).call
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
