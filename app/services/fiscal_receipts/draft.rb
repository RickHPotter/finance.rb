# frozen_string_literal: true

module FiscalReceipts
  Draft = Data.define(:access_key, :issuer, :issued_at, :total_cents, :items, :source) do
    def difference_cents
      total_cents - items.sum { |item| item.fetch(:price_cents) }
    end

    def as_json(*)
      {
        access_key:,
        issuer:,
        issued_at: issued_at&.iso8601,
        total_cents:,
        difference_cents:,
        items:,
        source:
      }
    end
  end
end
