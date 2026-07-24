# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Registry do
  it "registers the five locked financial-integrity checks" do
    expect(described_class.keys).to eq(
      %w[exchange_trio exchange_return card_exchange_projection misplaced_exchange_intent piggy_bank]
    )
    expect(described_class.entries.map(&:group).uniq).to eq([ "financial_integrity" ])
  end

  it "declares stable metadata and normalized runner/detail adapters" do
    expected_runners = {
      "exchange_trio" => HealthCheck::Checks::ExchangeTrio,
      "exchange_return" => HealthCheck::Checks::ExchangeReturn,
      "card_exchange_projection" => HealthCheck::Checks::CardExchangeProjection,
      "misplaced_exchange_intent" => HealthCheck::Checks::MisplacedExchangeIntent,
      "piggy_bank" => HealthCheck::Checks::PiggyBank
    }
    expected_details = {
      "exchange_trio" => HealthCheck::Checks::ExchangeTrioDetails,
      "exchange_return" => HealthCheck::Checks::ExchangeReturnDetails,
      "card_exchange_projection" => HealthCheck::Checks::CardExchangeProjectionDetails,
      "misplaced_exchange_intent" => HealthCheck::Checks::MisplacedExchangeIntentDetails,
      "piggy_bank" => HealthCheck::Checks::PiggyBankDetails
    }

    described_class.entries.each do |entry|
      expect(entry.title_key).to eq("health_check.checks.#{entry.key}.title")
      expect(entry.description_key).to eq("health_check.checks.#{entry.key}.description")
      expect(entry.severity).to eq("error")
      expect(entry.runner).to eq(expected_runners.fetch(entry.key))
      expect(entry.details).to eq(expected_details.fetch(entry.key))
    end
  end

  it "marks only the relationship checks as connected-user scoped" do
    connected_keys = described_class.entries.select(&:connection_scoped?).map(&:key)

    expect(connected_keys).to contain_exactly("exchange_trio", "misplaced_exchange_intent")
  end

  it "keeps Piggy Bank diagnostic-only while declaring the existing repair families" do
    expect(described_class.fetch(:exchange_trio).repair_keys).to eq([ "canonical_reference" ])
    expect(described_class.fetch(:exchange_return).repair_keys).to eq([ "source_allocation" ])
    expect(described_class.fetch(:card_exchange_projection).repair_keys).to eq([ "projection" ])
    expect(described_class.fetch(:misplaced_exchange_intent).repair_keys).to eq([ "convert_to_reimbursement" ])
    expect(described_class.fetch(:piggy_bank)).not_to be_repairable
  end

  it "returns nil for unknown lookup and raises for strict fetch" do
    expect(described_class.find(:unknown)).to be_nil
    expect { described_class.fetch(:unknown) }.to raise_error(KeyError)
  end

  it "does not expose mutable registry collections" do
    expect(described_class.entries).to be_frozen
    expect(described_class.keys).to be_frozen
    expect(described_class.entries).to all(be_frozen)
    expect(described_class.entries.flat_map(&:repair_keys)).to all(be_frozen)
  end
end
