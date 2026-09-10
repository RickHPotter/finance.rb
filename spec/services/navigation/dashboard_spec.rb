# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation::Dashboard do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }

  def destination(raw)
    described_class.new(raw:, current_user: user, current_context: context).destination
  end

  it "accepts context-owned financial and user-owned master-data dashboards" do
    account = create(:user_bank_account, :random, user:)
    user_card = create(:user_card, :random, user:)
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)
    cash_transaction = create(:cash_transaction, :random, user:, context:, user_bank_account: account)
    card_transaction = create(:card_transaction, :random, user:, context:, user_card:)
    budget = create(:budget, user:, context:)
    investment = create(:investment, user:, context:, user_bank_account: account, investment_type: create(:investment_type))
    subscription = create(:subscription, user:, context:)

    paths = [
      "/cash_transactions/#{cash_transaction.id}",
      "/card_transactions/#{card_transaction.id}",
      "/budgets/#{budget.id}",
      "/user_bank_accounts/#{account.id}",
      "/user_cards/#{user_card.id}",
      "/categories/#{category.id}",
      "/entities/#{entity.id}",
      "/investments/#{investment.id}",
      "/subscriptions/#{subscription.id}"
    ]

    expect(paths.map { |path| destination(path) }).to eq(paths)
  end

  it "rejects foreign, malformed, queried, and non-dashboard destinations" do
    foreign_user = create(:user, :random)
    foreign_transaction = create(:cash_transaction, :random, user: foreign_user, context: foreign_user.main_context)
    owned_transaction = create(:cash_transaction, :random, user:, context:)

    rejected = [
      "/cash_transactions/#{foreign_transaction.id}",
      "/cash_transactions/#{foreign_transaction.id}?return_to=/cash_transactions",
      "https://example.com/cash_transactions/#{owned_transaction.id}",
      "/cash_transactions",
      "//cash_transactions/#{foreign_transaction.id}"
    ]

    expect(rejected.map { |path| destination(path) }).to all(be_nil)
  end

  it "accepts validated report state only on reportable owned dashboards" do
    category = create(:category, :random, user:)
    raw = "/categories/#{category.id}?to_date=2026-09-30&from_date=2026-01-01&paid_state=pending&granularity=month"

    expect(destination(raw)).to eq(
      "/categories/#{category.id}?from_date=2026-01-01&granularity=month&paid_state=pending&to_date=2026-09-30"
    )
  end

  it "rejects invalid or oversized report state" do
    category = create(:category, :random, user:)

    rejected = [
      "/categories/#{category.id}?from_date=2026-09-30&to_date=2026-01-01",
      "/categories/#{category.id}?from_date=2024-01-01&to_date=2026-09-30",
      "/categories/#{category.id}?granularity=week"
    ]

    expect(rejected.map { |path| destination(path) }).to all(be_nil)
  end

  it "accepts only a validated Monthly Analysis return destination" do
    expect(destination("/balances?tab=monthly_analysis&month=2026-07")).to eq("/balances?month=2026-07&tab=monthly_analysis")

    rejected = [
      "/balances",
      "/balances?tab=overview&month=2026-07",
      "/balances?tab=monthly_analysis&month=2026-13",
      "https://example.com/balances?tab=monthly_analysis&month=2026-07"
    ]

    expect(rejected.map { |path| destination(path) }).to all(be_nil)
    expect(destination("/balances?tab=monthly_analysis&month=2026-07&unsafe=true")).to eq("/balances?month=2026-07&tab=monthly_analysis")
  end
end
