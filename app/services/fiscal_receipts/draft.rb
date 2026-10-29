# frozen_string_literal: true

module FiscalReceipts
  Draft = Data.define(:access_key, :issuer, :issued_at, :total_cents, :items, :source, :fiscal_details) do
    def initialize(access_key:, issuer:, issued_at:, total_cents:, items:, source:, fiscal_details: nil)
      super
    end

    def difference_cents
      total_cents - items.sum { |item| item.fetch(:price_cents) }
    end

    def as_json(*)
      result = {
        access_key:,
        issuer:,
        issued_at: issued_at&.iso8601,
        total_cents:,
        difference_cents:,
        items:,
        source:
      }
      result[:fiscal_details] = fiscal_details if fiscal_details.present?
      result
    end
  end
end
