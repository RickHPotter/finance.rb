# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::CanonicalRows do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }

  it "returns one typed row per context installment before allocation grouping" do
    category_a = create(:category, :random, user:)
    category_b = create(:category, :random, user:)
    cash_transaction = create_cash_transaction(price: 12_345, categories: [ category_a, category_b ])
    card_transaction = create_card_transaction(price: -4_567, categories: [ category_a, category_b ])

    rows = described_class.new(context:, query_state: month_state).call
    target_rows = rows.select do |row|
      [ row.transaction_type, row.transaction_id ].in?(
        [ [ "CashTransaction", cash_transaction.id ], [ "CardTransaction", card_transaction.id ] ]
      )
    end

    expect(target_rows.map(&:identity)).to contain_exactly(
      [ "CashInstallment", cash_transaction.cash_installments.sole.id ],
      [ "CardInstallment", card_transaction.card_installments.sole.id ]
    )
    expect(target_rows.map(&:amount_cents)).to contain_exactly(12_345, -4_567)
    expect(target_rows.map(&:movement_family)).to eq(%i[ordinary ordinary])
    expect(target_rows.map(&:to_h)).to all(include(period_key: "2026-07", occurred_on: Date.new(2026, 7, 1)))
    expect(rows.map(&:identity)).to eq(rows.map(&:identity).uniq)
    expect(rows).to include(have_attributes(movement_family: :generated_card_payment))
  end

  it "isolates the current context and applies installment paid state and direction" do
    included = create_cash_transaction(price: -1_000, paid: false)
    create_cash_transaction(price: 2_000, paid: true)
    create_cash_transaction(price: -3_000, paid: false, context: create(:context, user:))
    state = Reports::QueryState.new(
      { from_date: "2026-07-01", to_date: "2026-07-31", paid_state: "pending", direction: "outcome" }
    )

    rows = described_class.new(context:, query_state: state).call

    expect(rows.map(&:transaction_id)).to eq([ included.id ])
  end

  it "uses stored accounting month for month reports and the installment date for day reports" do
    transaction = create_card_transaction(price: -2_500)
    transaction.card_installments.sole.update_columns(date: Time.zone.local(2026, 6, 30, 12))

    july_rows = described_class.new(context:, query_state: month_state).call
    june_day_state = Reports::QueryState.new(
      { from_date: "2026-06-30", to_date: "2026-06-30", granularity: "day" }
    )
    june_rows = described_class.new(context:, query_state: june_day_state).call
    july_row = july_rows.find { |row| row.transaction_type == "CardTransaction" && row.transaction_id == transaction.id }
    june_row = june_rows.find { |row| row.transaction_type == "CardTransaction" && row.transaction_id == transaction.id }

    expect(july_row).to have_attributes(transaction_id: transaction.id, occurred_on: Date.new(2026, 7, 1), period_key: "2026-07")
    expect(june_row).to have_attributes(transaction_id: transaction.id, occurred_on: Date.new(2026, 6, 30), period_key: "2026-06-30")
  end

  it "classifies special rows with the shared movement classifier" do
    transfer = create_cash_transaction(price: -1_000)
    piggy_bank = create_cash_transaction(price: -2_000)
    create(:category_transaction, transactable: transfer, category: user.built_in_category("EXCHANGE"))
    create(:category_transaction, transactable: piggy_bank, category: user.built_in_category("PIGGY BANK"))
    piggy_bank.update_columns(cash_transaction_type: "PiggyBank")

    rows = described_class.new(context:, query_state: month_state).call.index_by(&:transaction_id)

    expect(rows.fetch(transfer.id).movement_family).to eq(:transfer)
    expect(rows.fetch(piggy_bank.id).movement_family).to eq(:piggy_bank)
  end

  it "accepts a bounded cash relation without loading card rows" do
    included = create_cash_transaction(price: -1_000)
    create_card_transaction(price: -2_000)
    cash_relation = context.cash_installments.joins(:cash_transaction).where(cash_transactions: { user_bank_account_id: account.id })

    rows = described_class.new(context:, query_state: month_state, cash_relation:, card_relation: nil).call

    expect(rows.map(&:identity)).to eq([ [ "CashInstallment", included.cash_installments.sole.id ] ])
  end

  private

  def month_state
    Reports::QueryState.new({ from_date: "2026-07-01", to_date: "2026-07-31" })
  end

  def create_cash_transaction(price:, categories: [], paid: false, context: self.context, cash_transaction_type: nil)
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      paid:,
      cash_transaction_type:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid:) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) }
    )
  end

  def create_card_transaction(price:, categories: [], paid: false)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: Date.new(2026, 6, 10),
      month: 7,
      year: 2026,
      price:,
      paid:,
      card_installments: [ build(:card_installment, number: 1, price:, date: Date.new(2026, 6, 10), month: 7, year: 2026, paid:) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) },
      entity_transactions: []
    )
  end
end
