# frozen_string_literal: true

class FiscalReceiptImportsController < ApplicationController
  def create
    file = params[:file]
    return render_error("Choose a fiscal XML file first.") unless file.respond_to?(:tempfile)
    return render_error("The fiscal file must be 10 MB or smaller.") if file.size > 10.megabytes
    return render_error("Only fiscal XML is supported in this import step.") unless File.extname(file.original_filename.to_s).casecmp?(".xml")

    draft = FiscalReceipts::XmlParser.new(file.read).call
    render json: { draft: draft.as_json }
  rescue FiscalReceipts::XmlParser::InvalidDocument => e
    render_error(e.message)
  end

  private

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
