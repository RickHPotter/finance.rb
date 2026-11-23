# frozen_string_literal: true

require "rails_helper"

RSpec.describe OcrExtractionJob, type: :job do
  let(:user) { create(:user, :random) }
  let(:draft) do
    user.fiscal_receipt_drafts.create!(
      status: :processing,
      payload: {}
    )
  end

  before do
    draft.source.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/files/ocr_naruto_08/clear_cupom.jpg"))),
      filename: "clear_cupom.jpg",
      content_type: "image/jpeg"
    )
  end

  describe "#perform" do
    let(:parsed_draft) do
      Ocr::ReceiptDraft.new(
        issuer: "MERCADO TESTE",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [
          { description: "ITEM 1", price_cents: 2500, confidence: :high, ocr_original: { description: "ITEM 1", price_cents: 2500 } }
        ],
        access_key: nil,
        field_confidences: { items: :high, total: :high },
        source_engine: "tesseract",
        processing_ms: 120
      )
    end

    it "runs pipeline and updates draft to ready on success" do
      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call).and_return([ "/tmp/mock_page.tiff" ])
      allow_any_instance_of(Ocr::TextExtractor).to receive(:call).and_return({ lines: [], raw_text: "test" })
      allow_any_instance_of(Ocr::ReceiptParser).to receive(:call).and_return(parsed_draft)

      expect do
        described_class.perform_now(draft.id)
      end.to change { draft.reload.status }.from("processing").to("ready")

      expect(draft.ocr_error).to be_nil
      expect(draft.payload).to include(
        "issuer" => "MERCADO TESTE",
        "total_cents" => 2500,
        "source" => "ocr"
      )
      expect(draft.payload.dig("ocr_details", "field_confidences")).to eq({ "items" => "high", "total" => "high" })
    end

    it "broadcasts replacement to user fiscal receipt stream on completion" do
      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call).and_return([ "/tmp/mock_page.tiff" ])
      allow_any_instance_of(Ocr::TextExtractor).to receive(:call).and_return({ lines: [], raw_text: "test" })
      allow_any_instance_of(Ocr::ReceiptParser).to receive(:call).and_return(parsed_draft)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        [ user, :fiscal_receipt_drafts ],
        target: "fiscal_receipt_draft_#{draft.id}",
        html: kind_of(String)
      )

      described_class.perform_now(draft.id)
    end

    it "marks draft as failed when image preprocessing fails" do
      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call)
        .and_raise(Ocr::ImagePreprocessor::UnsupportedFormat, "Image file is too large")

      described_class.perform_now(draft.id)

      draft.reload
      expect(draft.status).to eq("failed")
      expect(draft.ocr_error).to eq("Image file is too large")
    end

    it "marks draft as failed when text extraction fails" do
      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call).and_return([ "/tmp/mock_page.tiff" ])
      allow_any_instance_of(Ocr::TextExtractor).to receive(:call)
        .and_raise(Ocr::TextExtractor::ExtractionError, "No text found")

      described_class.perform_now(draft.id)

      draft.reload
      expect(draft.status).to eq("failed")
      expect(draft.ocr_error).to eq("No text found")
    end

    it "skips processing if draft is not in processing state" do
      draft.update_columns(status: "ready", payload: { "total_cents" => 100, "items" => [ { "description" => "A", "price_cents" => 100 } ] })
      expect_any_instance_of(Ocr::ImagePreprocessor).not_to receive(:call)

      described_class.perform_now(draft.id)
    end

    it "discards job when draft record is not found" do
      expect do
        described_class.perform_now(-999)
      end.not_to raise_error
    end

    it "attempts structured lookup when OCR extracts a Paraná access key and merges results" do
      pr_key = "41140978393592000146651000000000031222222235"
      ocr_result = Ocr::ReceiptDraft.new(
        issuer: "MERCADO",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [ { description: "ITEM 1", price_cents: 2500, confidence: :high } ],
        access_key: pr_key,
        field_confidences: {},
        source_engine: "tesseract",
        processing_ms: 100
      )
      structured_result = FiscalReceipts::Draft.new(
        access_key: pr_key,
        issuer: "MERCADO PR S/A",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [ { description: "ITEM 1 PR", price_cents: 2500 } ],
        source: "sefaz_pr"
      )

      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call).and_return([ "/tmp/mock.tiff" ])
      allow_any_instance_of(Ocr::TextExtractor).to receive(:call).and_return({ lines: [] })
      allow_any_instance_of(Ocr::ReceiptParser).to receive(:call).and_return(ocr_result)
      allow_any_instance_of(FiscalReceipts::ParanaLookup).to receive(:call).and_return(structured_result)

      described_class.perform_now(draft.id)

      draft.reload
      expect(draft.status).to eq("ready")
      expect(draft.payload["source"]).to eq("sefaz_pr")
      expect(draft.payload["issuer"]).to eq("MERCADO PR S/A")
      expect(draft.payload.dig("fiscal_details", "source_comparison")).to be_present
    end

    it "falls back to OCR-only draft when structured lookup fails" do
      pr_key = "41140978393592000146651000000000031222222235"
      ocr_result = Ocr::ReceiptDraft.new(
        issuer: "MERCADO LOCAL",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [ { description: "ITEM 1", price_cents: 2500, confidence: :high } ],
        access_key: pr_key,
        field_confidences: {},
        source_engine: "tesseract",
        processing_ms: 100
      )

      allow_any_instance_of(Ocr::ImagePreprocessor).to receive(:call).and_return([ "/tmp/mock.tiff" ])
      allow_any_instance_of(Ocr::TextExtractor).to receive(:call).and_return({ lines: [] })
      allow_any_instance_of(Ocr::ReceiptParser).to receive(:call).and_return(ocr_result)
      allow_any_instance_of(FiscalReceipts::ParanaLookup).to receive(:call)
        .and_raise(FiscalReceipts::ParanaLookup::Unavailable, "SEFAZ PR offline")

      described_class.perform_now(draft.id)

      draft.reload
      expect(draft.status).to eq("ready")
      expect(draft.payload["source"]).to eq("ocr")
      expect(draft.payload["issuer"]).to eq("MERCADO LOCAL")
    end
  end
end
