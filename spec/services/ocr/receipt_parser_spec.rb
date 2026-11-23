# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ocr::ReceiptParser do
  describe "#call" do
    let(:valid_access_key) { "41140978393592000146651000000000031222222235" }

    let(:standard_ocr_output) do
      {
        lines: [
          { text: "MERCADO EXERCICIO LTDA", confidence: 95.0, bbox: [ 10, 10, 200, 20 ] },
          { text: "CNPJ: 12.345.678/0001-90", confidence: 92.0, bbox: [ 10, 35, 200, 20 ] },
          { text: "EMISSAO: 14/10/2026 12:30:00", confidence: 90.0, bbox: [ 10, 60, 200, 20 ] },
          { text: "DESCRICAO QTD VL.UNIT VL.TOTAL", confidence: 88.0, bbox: [ 10, 85, 200, 20 ] },
          { text: "1 ARROZ TIPO 1 5KG 1 24,90 24,90", confidence: 92.0, bbox: [ 10, 110, 200, 20 ] },
          { text: "2 FEIJAO PRETO 1KG 2 8,50 17,00", confidence: 89.0, bbox: [ 10, 135, 200, 20 ] },
          { text: "TOTAL R$ 41,90", confidence: 96.0, bbox: [ 10, 160, 200, 20 ] },
          { text: "CHAVE DE ACESSO", confidence: 85.0, bbox: [ 10, 185, 200, 20 ] },
          { text: valid_access_key, confidence: 94.0, bbox: [ 10, 210, 200, 20 ] }
        ],
        raw_text: "full text",
        engine: "tesseract",
        language: "por+eng",
        processing_ms: 350
      }
    end

    it "extracts items, total, issuer, date, and access key from standard OCR output" do
      result = described_class.new(standard_ocr_output).call

      expect(result.issuer).to eq("MERCADO EXERCICIO LTDA")
      expect(result.total_cents).to eq(4190)
      expect(result.issued_at).to eq(Time.zone.local(2026, 10, 14, 12, 30, 0))
      expect(result.access_key).to eq(valid_access_key)
      expect(result.items.size).to eq(2)

      expect(result.items[0]).to include(
        description: "ARROZ TIPO 1 5KG",
        price_cents: 2490,
        confidence: :high
      )
      expect(result.items[1]).to include(
        description: "FEIJAO PRETO 1KG",
        price_cents: 1700,
        confidence: :high
      )

      expect(result.field_confidences).to include(
        items: :high,
        total: :high,
        issuer: :medium,
        issued_at: :high,
        access_key: :medium
      )
    end

    it "extracts items formatted with simple description and price pattern" do
      output = {
        lines: [
          { text: "SUPERMERCADO CENTRAL", confidence: 90.0 },
          { text: "ITEM DESCRICAO VALOR", confidence: 85.0 },
          { text: "LEITE INTEGRAL 1L 5,99", confidence: 88.0 },
          { text: "PAO FRANCES KG 12,50", confidence: 75.0 },
          { text: "VALOR TOTAL 18,49", confidence: 92.0 }
        ],
        engine: "tesseract",
        processing_ms: 200
      }

      result = described_class.new(output).call

      expect(result.items.size).to eq(2)
      expect(result.items[0][:description]).to eq("LEITE INTEGRAL 1L")
      expect(result.items[0][:price_cents]).to eq(599)
      expect(result.items[1][:description]).to eq("PAO FRANCES KG")
      expect(result.items[1][:price_cents]).to eq(1250)
      expect(result.items[1][:confidence]).to eq(:medium)
      expect(result.total_cents).to eq(1849)
    end

    it "handles unreadable item section gracefully with items_missing flag" do
      output = {
        lines: [
          { text: "LOJA EXEMPLO", confidence: 50.0 },
          { text: "TOTAL R$ 50,00", confidence: 88.0 }
        ],
        engine: "tesseract",
        processing_ms: 100
      }

      result = described_class.new(output).call

      expect(result.items).to be_empty
      expect(result.items_missing?).to be(true)
      expect(result.total_cents).to eq(5000)
      expect(result.field_confidences[:items]).to eq(:low)
    end

    it "converts to a FiscalReceipts::Draft with source 'ocr' and original values in fiscal_details" do
      result = described_class.new(standard_ocr_output).call
      fiscal_draft = result.to_fiscal_draft

      expect(fiscal_draft).to be_a(FiscalReceipts::Draft)
      expect(fiscal_draft.source).to eq("ocr")
      expect(fiscal_draft.total_cents).to eq(4190)
      expect(fiscal_draft.items.map { |i| i[:description] }).to eq([ "ARROZ TIPO 1 5KG", "FEIJAO PRETO 1KG" ])
      expect(fiscal_draft.fiscal_details).to include(
        ocr_engine: "tesseract",
        ocr_processing_ms: 350
      )
      expect(fiscal_draft.fiscal_details[:ocr_originals].size).to eq(2)
    end

    it "skips invalid access keys" do
      output = {
        lines: [
          { text: "12345678901234567890123456789012345678901234", confidence: 80.0 }
        ],
        engine: "tesseract"
      }

      result = described_class.new(output).call
      expect(result.access_key).to be_nil
      expect(result.field_confidences[:access_key]).to eq(:low)
    end
  end
end
