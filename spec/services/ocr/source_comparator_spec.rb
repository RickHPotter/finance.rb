# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ocr::SourceComparator do
  describe "#call" do
    let(:access_key) { "41140978393592000146651000000000031222222235" }

    let(:structured_draft) do
      FiscalReceipts::Draft.new(
        access_key: access_key,
        issuer: "MERCADO EXEMPLO LTDA",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [
          { description: "ARROZ TIPO 1", price_cents: 2500 }
        ],
        source: "sefaz_pr",
        fiscal_details: { model: "65" }
      )
    end

    let(:matching_ocr_draft) do
      Ocr::ReceiptDraft.new(
        issuer: "MERCADO EXEMPLO LTDA",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [
          { description: "ARROZ TIPO 1", price_cents: 2500, confidence: :high, ocr_original: { description: "ARROZ TIPO 1", price_cents: 2500 } }
        ],
        access_key: access_key,
        field_confidences: { total: :high, items: :high },
        source_engine: "tesseract",
        processing_ms: 100
      )
    end

    it "produces matches and no review required when structured and OCR agree" do
      comparator = described_class.new(structured_draft:, ocr_draft: matching_ocr_draft)
      merged = comparator.call

      expect(merged.source).to eq("sefaz_pr")
      expect(merged.total_cents).to eq(2500)
      expect(merged.fiscal_details[:review_required]).to be(false)

      comparisons = merged.fiscal_details[:source_comparison]
      expect(comparisons).to include(
        { field: :total_cents, structured: 2500, ocr: 2500, status: :match },
        { field: :access_key, structured: access_key, ocr: access_key, status: :match },
        { field: :item_count, structured: 1, ocr: 1, status: :match }
      )
    end

    it "flags conflict and requires review when amounts or items differ" do
      conflicting_ocr_draft = Ocr::ReceiptDraft.new(
        issuer: "MERCADO EXEMPLO LTDA",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 3000,
        items: [
          { description: "ARROZ TIPO 1", price_cents: 1500, confidence: :high },
          { description: "FEIJAO", price_cents: 1500, confidence: :medium }
        ],
        access_key: access_key,
        field_confidences: { total: :high, items: :medium },
        source_engine: "tesseract",
        processing_ms: 100
      )

      comparator = described_class.new(structured_draft:, ocr_draft: conflicting_ocr_draft)
      merged = comparator.call

      expect(merged.fiscal_details[:review_required]).to be(true)
      expect(merged.total_cents).to eq(2500) # Structured wins

      comparisons = merged.fiscal_details[:source_comparison]
      expect(comparisons).to include(
        { field: :total_cents, structured: 2500, ocr: 3000, status: :conflict },
        { field: :item_count, structured: 1, ocr: 2, status: :conflict }
      )
    end

    it "handles fuzzy issuer matching without conflict" do
      ocr_with_abbreviated_issuer = Ocr::ReceiptDraft.new(
        issuer: "MERCADO EXEMPLO",
        issued_at: Time.zone.local(2026, 10, 14, 12, 30),
        total_cents: 2500,
        items: [
          { description: "ARROZ TIPO 1", price_cents: 2500, confidence: :high }
        ],
        access_key: access_key,
        field_confidences: {},
        source_engine: "tesseract",
        processing_ms: 100
      )

      comparator = described_class.new(structured_draft:, ocr_draft: ocr_with_abbreviated_issuer)
      merged = comparator.call

      issuer_comparison = merged.fiscal_details[:source_comparison].find { |c| c[:field] == :issuer }
      expect(issuer_comparison[:status]).to eq(:match)
      expect(merged.fiscal_details[:review_required]).to be(false)
    end
  end
end
