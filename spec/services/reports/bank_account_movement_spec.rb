# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::BankAccountMovement do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:, balance: 7_777) }
  let(:query_state) { Reports::QueryState.new({ from_date: "2026-07-01", to_date: "2026-07-31" }) }

  it "reconciles payment state, movement families, exact sources, and stored balance observations" do
    ordinary = create_transaction(price: 1_000, paid: true, balance: 10_000, order_id: 1)
    transfer = create_transaction(price: -2_000, paid: false, category_name: "EXCHANGE", balance: 8_000, order_id: 2)
    create_transaction(price: 3_000, paid: true, category_name: "FAILED LEND/BORROW RETURN")
    create_transaction(price: -4_000, paid: false, category_name: "PIGGY BANK", cash_transaction_type: "PiggyBank")
    create_transaction(price: 5_000, paid: true, cash_transaction_type: "CardInstallment")
    create_transaction(price: -6_000, paid: false, cash_transaction_type: "Investment")
    create_transaction(price: 70_000, user_bank_account: create(:user_bank_account, :random, user:))
    create_transaction(price: 80_000, transaction_context: create(:context, user:))
    account_installments.update_all(balance: nil, order_id: nil)
    ordinary.cash_installments.sole.update_columns(balance: 10_000, order_id: 1)
    transfer.cash_installments.sole.update_columns(balance: 8_000, order_id: 2)

    payload = described_class.new(context:, user_bank_account: account, query_state:).call

    expect(payload[:resource]).to eq(type: "UserBankAccount", id: account.id, label: account.user_bank_account_name)
    expect(payload[:summary]).to include(net_cents: -3_000)
    expect(payload.dig(:summary, :income)).to include(amount_cents: 9_000, source_count: 3)
    expect(payload.dig(:summary, :outcome)).to include(amount_cents: 12_000, source_count: 3)
    expect(payload[:payment_states]).to contain_exactly(
      include(key: :paid, net_cents: 9_000),
      include(key: :pending, net_cents: -12_000)
    )
    expect(payload[:breakdowns].pluck(:key)).to eq(described_class::FAMILIES)
    expect(payload[:breakdowns].sum { |family| family[:net_cents] }).to eq(payload.dig(:summary, :net_cents))
    expect(payload[:buckets].sole).to include(key: "2026-07", net_cents: -3_000)

    expect(payload[:balance_context]).to include(account_balance_cents: 7_777, recorded_count: 2)
    expect(payload.dig(:balance_context, :first_recorded)).to include(amount_cents: 10_000, installment_id: ordinary.cash_installments.sole.id, order_id: 1)
    expect(payload.dig(:balance_context, :latest_recorded)).to include(amount_cents: 8_000, installment_id: transfer.cash_installments.sole.id, order_id: 2)

    transfer_family = payload[:breakdowns].find { |family| family[:key] == :transfer }
    source_path = transfer_family.dig(:outcome, :sources, :cash, :chunks, 0, :path)
    query = Rack::Utils.parse_nested_query(URI.parse(source_path).query)
    expect(query.dig("cash_transaction", "cash_installment_ids")).to eq([ transfer.cash_installments.sole.id.to_s ])
    expect(Navigation::Dashboard.new(raw: query.fetch("return_to"), current_user: user, current_context: context).destination).to eq(query.fetch("return_to"))
  end

  it "applies direction and paid state without hiding the reconciling payment-state totals" do
    create_transaction(price: 1_000, paid: true)
    transfer = create_transaction(price: -2_000, paid: false, category_name: "EXCHANGE")
    create_transaction(price: -3_000, paid: true, category_name: "PIGGY BANK")
    filtered_state = Reports::QueryState.new(
      {
        from_date: "2026-07-01",
        to_date: "2026-07-31",
        paid_state: "pending",
        direction: "outcome"
      }
    )

    payload = described_class.new(context:, user_bank_account: account, query_state: filtered_state).call

    expect(payload[:summary]).to include(net_cents: -2_000)
    expect(payload.dig(:summary, :outcome)).to include(amount_cents: 2_000, source_count: 1)
    expect(payload.dig(:summary, :income, :amount_cents)).to eq(0)
    expect(payload[:breakdowns].pluck(:key)).to eq([ :transfer ])
    expect(payload[:payment_states]).to contain_exactly(
      include(key: :paid, net_cents: -3_000),
      include(key: :pending, net_cents: -2_000)
    )
    expect(payload.dig(:summary, :outcome, :sources, :cash, :chunks, 0, :path)).to include(transfer.cash_installments.sole.id.to_s)
  end

  it "keeps account report query count bounded as rows grow" do
    create_transaction(price: -100)
    baseline_count = count_select_queries { described_class.new(context:, user_bank_account: account, query_state:).call }

    4.times { |index| create_transaction(price: -(index + 2) * 100) }
    expanded_count = count_select_queries { described_class.new(context:, user_bank_account: account, query_state:).call }

    expect(expanded_count).to eq(baseline_count)
  end

  private

  def create_transaction(price:, paid: false, category_name: nil, balance: nil, order_id: nil, cash_transaction_type: nil, user_bank_account: account,
                         transaction_context: context)
    transaction = create(
      :cash_transaction,
      user:,
      context: transaction_context,
      user_bank_account:,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      paid:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid:) ]
    )
    create(:category_transaction, transactable: transaction, category: user.built_in_category(category_name)) if category_name
    transaction.update_columns(cash_transaction_type:) if cash_transaction_type
    transaction.cash_installments.sole.update_columns(balance:, order_id:) if balance || order_id
    transaction
  end

  def count_select_queries(&)
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, data|
      queries << data[:sql] if data[:sql].start_with?("SELECT") && !data[:cached]
    end

    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &)
    end
    queries.size
  end

  def account_installments
    CashInstallment.joins(:cash_transaction).where(cash_transactions: { user_bank_account_id: account.id, context_id: context.id })
  end
end
