# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::BudgetPerformance do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:food) { create(:category, :random, user:, category_name: "FOOD") }
  let(:needs) { create(:category, :random, user:, category_name: "NEEDS") }
  let(:entity) { create(:entity, :random, user:, entity_name: "MARKET") }

  def create_cash(description:, price:, month: 9, year: 2026, categories: [ food ], entities: [])
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: bank_account,
      description:,
      date: Date.new(year, month, 10),
      month:,
      year:,
      price:,
      cash_installments: [ build(:cash_installment, number: 1, date: Date.new(year, month, 10), month:, year:, price:, paid: true) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) },
      entity_transactions: entities.map { |record| EntityTransaction.new(entity: record, price: 0, is_payer: false) }
    )
  end

  def create_card(description:, price:, month: 9, year: 2026, categories: [ food ], entities: [])
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      description:,
      date: Date.new(year, month, 8),
      month:,
      year:,
      price:,
      card_installments: [ build(:card_installment, number: 1, date: Date.new(year, month, 8), month:, year:, price:, paid: false) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) },
      entity_transactions: entities.map { |record| EntityTransaction.new(entity: record, price: 0, is_payer: false) }
    )
  end

  def create_budget(**attributes)
    create(
      :budget,
      user:,
      context:,
      month: 9,
      year: 2026,
      value: -10_000,
      budget_categories: [ build(:budget_category, category: food) ],
      **attributes
    )
  end

  it "reconciles unique mixed cash and card sources with the stored budget calculation" do
    cash = create_cash(description: "Cash groceries", price: -2_500, categories: [ food, needs ])
    card = create_card(description: "Card groceries", price: -1_500, categories: [ food, needs ])
    budget = create_budget(budget_categories: [ build(:budget_category, category: food), build(:budget_category, category: needs) ])

    payload = described_class.new(budget:, today: Date.new(2026, 9, 15)).call

    expect(payload[:performance]).to include(actual_cents: -4_000, remaining_cents: -6_000, utilization_percentage: 40.0, period_completion_percentage: 50.0,
                                             status: "available")
    expect(payload.dig(:definition, :recorded_remaining_cents)).to eq(budget.remaining_value)
    expect(payload.dig(:sources, :cash)).to include(amount_cents: -2_500, count: 1)
    expect(payload.dig(:sources, :card)).to include(amount_cents: -1_500, count: 1)
    expect(payload.dig(:sources, :cash, :chunks, 0, :amount_cents)).to eq(-2_500)
    expect(payload.dig(:sources, :card, :chunks, 0, :amount_cents)).to eq(-1_500)
    expect(payload.dig(:sources, :cash, :chunks, 0, :path)).to include("cash_transaction%5Bcash_installment_ids%5D%5B%5D=#{cash.cash_installments.first.id}")
    expect(payload.dig(:sources, :card, :chunks, 0, :path)).to include("card_transaction%5Bcard_installment_ids%5D%5B%5D=#{card.card_installments.first.id}")
    expect(budget.value - budget.remaining_value).to eq(payload.dig(:performance, :actual_cents))
  end

  it "retains inclusive and first-installment-only membership" do
    matching = create_cash(description: "Matching", price: -2_000, entities: [ entity ])
    matching.cash_installments.create!(number: 2, cash_installments_count: 2, date: Date.new(2026, 9, 20), month: 9, year: 2026, price: -1_000,
                                       starting_price: -1_000, paid: false)
    matching.cash_installments.first.update_columns(price: -1_000, starting_price: -1_000, cash_installments_count: 2)
    create_cash(description: "Category only", price: -3_000)
    budget = create_budget(
      inclusive: true,
      first_installment_only: true,
      budget_entities: [ build(:budget_entity, entity:) ]
    )

    payload = described_class.new(budget:).call

    expect(payload.dig(:performance, :actual_cents)).to eq(-1_000)
    expect(payload[:rules]).to include(inclusive: true, first_installment_only: true, allocation_operator: "all")
    expect(payload.dig(:sources, :cash, :count)).to eq(1)
  end

  it "keeps empty, inactive, overspent, future, and completed periods truthful without writing" do
    empty_budget = create_budget(month: 10, active: false)
    overspent_source = create_cash(description: "Overspent", price: -12_000, month: 8)
    overspent_budget = create_budget(month: 8, active: false)
    timestamps = [ empty_budget.reload.updated_at, overspent_budget.reload.updated_at, overspent_source.reload.updated_at ]

    empty_payload = described_class.new(budget: empty_budget, today: Date.new(2026, 9, 10)).call
    overspent_payload = described_class.new(budget: overspent_budget, today: Date.new(2026, 9, 10)).call

    expect(empty_payload[:performance]).to include(actual_cents: 0, remaining_cents: -10_000, utilization_percentage: 0.0, period_completion_percentage: 0.0)
    expect(empty_payload.dig(:definition, :active)).to be(false)
    expect(overspent_payload[:performance]).to include(actual_cents: -12_000, remaining_cents: 2_000, utilization_percentage: 120.0,
                                                       period_completion_percentage: 100.0, status: "exceeded")
    expect(overspent_payload.dig(:definition, :recorded_remaining_cents)).to eq(0)
    expect([ empty_budget.reload.updated_at, overspent_budget.reload.updated_at, overspent_source.reload.updated_at ]).to eq(timestamps)
  end

  it "uses the same exchange-adjusted amount as Budget recalculation" do
    transaction = create_cash(description: "Exchange-adjusted source", price: -1_000, entities: [ entity ])
    entity_transaction = transaction.entity_transactions.sole
    create(:exchange, entity_transaction:, price: -300, month: 9, year: 2026, date: Date.new(2026, 9, 10))
    budget = create_budget

    payload = described_class.new(budget:).call

    expect(payload.dig(:performance, :actual_cents)).to eq(-1_300)
    expect(budget.value - budget.remaining_value).to eq(-1_300)
  end

  it "keeps report query count bounded as matching rows grow" do
    create_cash(description: "Baseline", price: -100)
    budget = create_budget
    baseline_count = count_select_queries { described_class.new(budget: budget.reload).call }

    5.times { |index| create_cash(description: "Expanded #{index}", price: -100) }
    expanded_count = count_select_queries { described_class.new(budget: budget.reload).call }

    expect(expanded_count).to be <= baseline_count + 2
  end

  def count_select_queries(&)
    queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, data|
      queries << data[:sql] if data[:sql].start_with?("SELECT") && !data[:cached]
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
    queries.size
  end
end
