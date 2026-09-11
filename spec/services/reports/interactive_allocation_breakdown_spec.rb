# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::InteractiveAllocationBreakdown do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:food) { create(:category, user:, category_name: "FOOD") }
  let(:home) { create(:category, user:, category_name: "HOME") }
  let(:ana) { create(:entity, user:, entity_name: "ANA") }
  let(:query_state) { Reports::QueryState.new({ from_date: "2026-07-01", to_date: "2026-08-31" }) }

  it "precomputes exact, combination, and all-group category series from canonical installment rows" do
    create_transaction(price: -1_000, date: Date.new(2026, 7, 10), categories: [ food ], entities: [ ana ])
    create_transaction(price: -2_000, date: Date.new(2026, 8, 10), categories: [ food, home ], entities: [ ana ])

    payload = described_class.new(rows: canonical_rows, query_state:, primary_dimension: :category).call
    food_entry = payload[:items].find { |item| item[:id] == food.id.to_s }

    expect(payload).to include(primary_kind: :category, secondary_kind: :entity, granularity: "month")
    expect(payload[:periods]).to eq(%w[2026-07-01 2026-08-01])
    expect(food_entry[:groups].pluck(:id)).to eq([ "__all__", [ food.id, home.id ].sort.join("-") ])
    expect(food_entry[:all_secondary_items].sole).to include(
      id: ana.id.to_s,
      total_cents: -3_000,
      points: [ { x: "2026-07-01", amount_cents: -1_000 }, { x: "2026-08-01", amount_cents: -2_000 } ]
    )
  end

  it "keeps category-bundle presentation in the entity-first dashboard" do
    create_transaction(price: -2_000, date: Date.new(2026, 8, 10), categories: [ food, home ], entities: [ ana ])

    payload = described_class.new(rows: canonical_rows, query_state:, primary_dimension: :entity).call
    category_bundle = payload.dig(:items, 0, :all_secondary_items, 0)

    expect(payload).to include(primary_kind: :entity, secondary_kind: :category)
    expect(category_bundle).to include(name: "FOOD / HOME", total_cents: -2_000)
    expect(category_bundle[:chart_presentation]).to include(:background, :foreground)
    expect(category_bundle[:swatches].pluck(:id)).to contain_exactly(food.id, home.id)
  end

  private

  def create_transaction(price:, date:, categories:, entities:)
    transaction = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      date:,
      month: date.month,
      year: date.year,
      price:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date:, month: date.month, year: date.year) ],
      category_transactions: [],
      entity_transactions: []
    )
    categories.each { |category| create(:category_transaction, transactable: transaction, category:) }
    entities.each { |entity| create(:entity_transaction, transactable: transaction, entity:) }
    transaction
  end

  def canonical_rows
    Reports::CanonicalRows.new(
      context:,
      query_state:,
      cash_relation: context.cash_installments.joins(:cash_transaction).where(cash_transactions: { user_bank_account_id: account.id }),
      card_relation: nil
    ).call
  end
end
