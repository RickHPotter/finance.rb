# frozen_string_literal: true

class FiscalReceiptImportsController < ApplicationController
  def create
    file = params[:file]
    draft = file.respond_to?(:tempfile) ? draft_from_file(file) : draft_from_source(params[:source])
    render json: { draft: draft.as_json }
  rescue FiscalReceipts::XmlParser::InvalidDocument, FiscalReceipts::ParanaLookup::Unavailable,
         FiscalReceipts::SourceKey::InvalidSource, FiscalReceipts::PdfKeyExtractor::Unreadable => e
    render_error(e.message)
  end

  private

  def draft_from_file(file)
    raise FiscalReceipts::XmlParser::InvalidDocument, "The fiscal file must be 10 MB or smaller." if file.size > 10.megabytes

    case File.extname(file.original_filename.to_s).downcase
    when ".xml" then FiscalReceipts::XmlParser.new(file.read).call
    when ".pdf" then FiscalReceipts::ParanaLookup.new(FiscalReceipts::PdfKeyExtractor.new(file).call).call
    else raise FiscalReceipts::XmlParser::InvalidDocument, "Upload a fiscal XML, PDF, or a readable QR image."
    end
  end

  def draft_from_source(source)
    key = FiscalReceipts::SourceKey.new(source).call
    FiscalReceipts::ParanaLookup.new(key).call
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
