# frozen_string_literal: true

module Ocr
  ReceiptDraft = Data.define(
    :issuer, :issued_at, :total_cents, :items, :access_key,
    :field_confidences, :source_engine, :processing_ms
  ) do
    def initialize(issuer:, issued_at:, total_cents:, items:, access_key:,
                   field_confidences: {}, source_engine: "tesseract", processing_ms: 0)
      super
    end

    def to_fiscal_draft
      FiscalReceipts::Draft.new(
        access_key: access_key,
        issuer: issuer,
        issued_at: issued_at,
        total_cents: total_cents || items_total_cents,
        items: items.map do |item|
          {
            description: item[:description] || item["description"],
            price_cents: item[:price_cents] || item["price_cents"],
            confidence: item[:confidence] || item["confidence"],
            ocr_original: item[:ocr_original] || item["ocr_original"]
          }.compact
        end,
        source: "ocr",
        fiscal_details: ocr_fiscal_details
      )
    end

    def items_total_cents
      items.sum { |item| item[:price_cents] }
    end

    def items_missing?
      field_confidences[:items_missing] == true
    end

    private

    def ocr_fiscal_details
      {
        ocr_engine: source_engine,
        ocr_processing_ms: processing_ms,
        field_confidences: field_confidences.transform_values(&:to_s),
        ocr_originals: items.filter_map { |item| item[:ocr_original] }
      }
    end
  end
end
