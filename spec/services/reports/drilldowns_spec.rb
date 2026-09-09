# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::Drilldowns do
  let(:row_class) { Data.define(:installment_type, :installment_id, :amount_cents) }

  it "chunks exact source identities at the navigation limit and reconciles each chunk" do
    rows = Array.new(51) do |index|
      row_class.new(installment_type: "CashInstallment", installment_id: index + 1, amount_cents: -(index + 1))
    end

    result = described_class.new(rows:, return_to: "/categories/1").call

    expect(result[:cash]).to include(count: 51, amount_cents: 1_326)
    expect(result.dig(:cash, :chunks).pluck(:count)).to eq([ 49, 2 ])
    expect(result.dig(:cash, :chunks).sum { |chunk| chunk[:amount_cents] }).to eq(1_326)
    expect(result[:card]).to eq(count: 0, amount_cents: 0, chunks: [])

    result.dig(:cash, :chunks).each do |chunk|
      query = Rack::Utils.parse_nested_query(URI.parse(chunk[:path]).query)
      expect(query.dig("cash_transaction", "cash_installment_ids").size + 1).to be <= Navigation::State::MAX_VALUES
      expect(query["return_to"]).to eq("/categories/1")
    end
  end
end
