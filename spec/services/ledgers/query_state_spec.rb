# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledgers::QueryState, type: :service do
  it "parses and canonically serializes the bounded cash ledger allowlist" do
    state = described_class.new(
      kind: :cash,
      params: {
        active_month_years: "[202610,202609,202609,202613,1]",
        default_year: "2026",
        month_year: "202609",
        search_term: "  café   invoice  ",
        paid: "true",
        pending: "false",
        sort: "price",
        direction: "desc",
        page: "2",
        per_page: "25",
        force_mobile: "1",
        ignored_private_filter: "secret",
        cash_transaction: { user_bank_account_id: [ "17" ], user_id: "999", entity_id: "999" }
      }
    )

    expect(state).to have_attributes(
      month_year: 202_609,
      active_month_years: [ 202_609, 202_610 ],
      default_year: 2026,
      search_term: "café invoice",
      paid: true,
      pending: false,
      sort: "price",
      direction: "desc",
      page: 2,
      per_page: 25,
      user_bank_account_id: 17,
      force_mobile: true
    )
    expect(state.canonical_params).not_to include(:ignored_private_filter, :user_id, :entity_id)
    expect(state.canonical_params[:month_year]).to eq(202_609)
    expect(state.canonical_params[:cash_transaction]).to eq(user_bank_account_id: 17)
  end

  it "normalizes invalid and reversed card state without interpolating it into ordering" do
    state = described_class.new(
      kind: :card,
      params: {
        active_month_years: "not-json",
        default_year: "9999",
        month_year: "202600",
        sort: "price; DROP TABLE installments",
        direction: "sideways",
        page: "-2",
        per_page: "10000",
        card_transaction: { user_card_id: "bad" }
      }
    )

    expect(state).to have_attributes(
      month_year: nil,
      active_month_years: [],
      default_year: nil,
      sort: "installment_date",
      direction: "asc",
      page: 1,
      per_page: described_class::DEFAULT_PER_PAGE,
      user_card_id: nil
    )
  end

  it "rejects unsupported ledger kinds" do
    expect { described_class.new(kind: :investment, params: {}) }.to raise_error(ArgumentError, /Unsupported ledger kind/)
  end
end
