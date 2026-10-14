# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fiscal receipt imports", type: :request do
  let(:user) { create(:user, :random) }

  describe "POST /fiscal_receipt_imports" do
    it "returns an unsaved draft from an authorized fiscal XML" do
      sign_in user
      receipt = fixture_file_upload("fiscal_receipt.xml", "application/xml")

      expect do
        post fiscal_receipt_imports_path, params: { file: receipt }, headers: { "Accept" => "application/json" }
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:ok)
      draft = response.parsed_body.fetch("draft")
      expect(draft.fetch("total_cents")).to eq(1975)
      expect(draft.fetch("items")).to eq([
                                           { "description" => "Arroz", "price_cents" => 1150 },
                                           { "description" => "Feijao", "price_cents" => 825 }
                                         ])
    end

    it "rejects unsupported files" do
      sign_in user
      receipt = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"), "application/pdf", original_filename: "receipt.pdf")

      post fiscal_receipt_imports_path, params: { file: receipt }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires authentication" do
      receipt = fixture_file_upload("fiscal_receipt.xml", "application/xml")

      post fiscal_receipt_imports_path, params: { file: receipt }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
    end
  end
end
