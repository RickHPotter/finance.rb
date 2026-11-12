# frozen_string_literal: true

module FiscalReceipts
  Draft = Data.define(:access_key, :issuer, :issued_at, :total_cents, :items, :source, :fiscal_details, :discount_cents, :freight_cents) do
    def initialize(access_key:, issuer:, issued_at:, total_cents:, items:, source:, fiscal_details: nil, discount_cents: 0, freight_cents: 0)
      super
    end

    def difference_cents
      total_cents - items.sum { |item| item.fetch(:price_cents) } + discount_cents - freight_cents
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
      result[:discount_cents] = discount_cents if discount_cents.positive?
      result[:freight_cents] = freight_cents if freight_cents.positive?
      result
    end
  end
end
