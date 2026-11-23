# frozen_string_literal: true

module Ocr
  class SourceComparator
    def initialize(structured_draft:, ocr_draft:)
      @structured = structured_draft
      @ocr = ocr_draft.respond_to?(:to_fiscal_draft) ? ocr_draft.to_fiscal_draft : ocr_draft
      @ocr_raw = ocr_draft
    end

    def call
      comp = comparisons
      FiscalReceipts::Draft.new(
        access_key: @structured.access_key.presence || @ocr.access_key,
        issuer: @structured.issuer.presence || @ocr.issuer,
        issued_at: @structured.issued_at || @ocr.issued_at,
        total_cents: @structured.total_cents || @ocr.total_cents,
        items: @structured.items.presence || @ocr.items,
        source: @structured.source,
        fiscal_details: build_merged_fiscal_details(comp),
        discount_cents: @structured.discount_cents,
        freight_cents: @structured.freight_cents
      )
    end

    def comparisons
      @comparisons ||= build_comparisons
    end

    private

    def build_merged_fiscal_details(comp)
      details = (@structured.fiscal_details || {}).deep_symbolize_keys
      details.merge(
        source_comparison: comp,
        review_required: comp.any? { |c| c[:status] == :conflict },
        ocr_total_cents: @ocr.total_cents,
        ocr_issuer: @ocr.issuer,
        ocr_item_count: @ocr.items.size
      )
    end

    def build_comparisons
      [
        compare_total,
        compare_access_key,
        compare_issuer,
        compare_item_count
      ].compact
    end

    def compare_total
      return unless @structured.total_cents && @ocr.total_cents

      status = @structured.total_cents == @ocr.total_cents ? :match : :conflict
      { field: :total_cents, structured: @structured.total_cents, ocr: @ocr.total_cents, status: status }
    end

    def compare_access_key
      return unless @structured.access_key.present? && @ocr.access_key.present?

      status = @structured.access_key == @ocr.access_key ? :match : :conflict
      { field: :access_key, structured: @structured.access_key, ocr: @ocr.access_key, status: status }
    end

    def compare_issuer
      return unless @structured.issuer.present? && @ocr.issuer.present?

      norm_struct = normalize_text(@structured.issuer)
      norm_ocr = normalize_text(@ocr.issuer)
      status = norm_struct == norm_ocr || norm_struct.include?(norm_ocr) || norm_ocr.include?(norm_struct) ? :match : :conflict

      { field: :issuer, structured: @structured.issuer, ocr: @ocr.issuer, status: status }
    end

    def compare_item_count
      struct_size = @structured.items&.size || 0
      ocr_size = @ocr.items&.size || 0

      status = struct_size == ocr_size ? :match : :conflict
      { field: :item_count, structured: struct_size, ocr: ocr_size, status: status }
    end

    def normalize_text(text)
      text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end
  end
end
