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

    it "returns Paraná NFC-e items from a 44-digit key" do
      sign_in user
      key = "41140978393592000146651000000000031222222235"
      html = <<~HTML
        <div id="u20">Mercado Exemplo</div>
        <table id="tabResult"><tr><td><span class="txtTit2">Arroz</span></td><td class="txtTit3">Vl. Total 12,50</td></tr></table>
        <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">12,50</span></div>
      HTML
      stub_request(:get, %r{www\.fazenda\.pr\.gov\.br/nfce/qrcode}).to_return(status: 200, body: html)

      post fiscal_receipt_imports_path, params: { source: key }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("draft", "items").first.fetch("price_cents")).to eq(1250)
    end

    it "extracts a fiscal key from a text PDF before looking up its items" do
      sign_in user
      key = "41140978393592000146651000000000031222222235"
      pdf = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"), "application/pdf", original_filename: "receipt.pdf")
      allow(FiscalReceipts::PdfKeyExtractor).to receive(:new).and_return(instance_double(FiscalReceipts::PdfKeyExtractor, call: key))
      html = <<~HTML
        <table id="tabResult"><tr><td><span class="txtTit2">Arroz</span></td><td class="txtTit3">Vl. Total 12,50</td></tr></table>
        <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb">12,50</span></div>
      HTML
      stub_request(:get, %r{www\.fazenda\.pr\.gov\.br/nfce/qrcode}).to_return(status: 200, body: html)

      post fiscal_receipt_imports_path, params: { file: pdf }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("draft", "source")).to eq("sefaz_pr")
    end

    it "imports Goiás items from the full signed QR URL" do
      sign_in user
      key = "52260301427744000150650010005752241062577988"
      source = "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe?p=#{key}|2|1|1|8063029A08AC070E0D5C6DDB0891AC3F116830AC"
      draft = FiscalReceipts::Draft.new(access_key: key, issuer: "Mercado", issued_at: nil, total_cents: 1250,
                                        items: [ { description: "Arroz", price_cents: 1250 } ], source: "sefaz_go")
      allow(FiscalReceipts::GoiasLookup).to receive(:new).with(source).and_return(instance_double(FiscalReceipts::GoiasLookup, call: draft))

      post fiscal_receipt_imports_path, params: { source: }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("draft", "source")).to eq("sefaz_go")
      expect(response.parsed_body.dig("draft", "items", 0, "price_cents")).to eq(1250)
    end

    it "explains why a bare Goiás key cannot be looked up automatically" do
      sign_in user

      post fiscal_receipt_imports_path, params: { source: "52260301427744000150650010005752241062577988" },
                                        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.fetch("error")).to include("complete QR URL")
    end

    it "requires authentication" do
      receipt = fixture_file_upload("fiscal_receipt.xml", "application/xml")

      post fiscal_receipt_imports_path, params: { file: receipt }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
    end
  end
end
