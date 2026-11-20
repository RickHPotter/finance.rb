# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBankReconciliations::CalculateSafeInstallmentDate do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:reference_date) { Date.new(2026, 11, 10) }

  let(:return_transaction) { create_piggy_bank_return }

  around do |example|
    travel_to reference_date.in_time_zone do
      example.run
    end
  end

  def create_piggy_bank_return(price: 5_000, return_date: Date.new(2026, 12, 1))
    source = build(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description: "Observed reserve",
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Date.new(2026, 9, 1)) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date:)
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  # Creates the given cash flows and refreshes the balance timeline the way the application
  # does, so the running balance and the order ids match the production data.
  def build_balance_timeline(flows)
    flows.each do |date, price|
      create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        description: "Timeline #{date}",
        price: price,
        date: date,
        cash_installments: [ build(:cash_installment, number: 1, price:, date:) ]
      )
    end

    running_balance = 0
    context.cash_installments.reorder(:date, :id).each_with_index do |installment, index|
      running_balance += installment.price
      installment.update_columns(balance: running_balance, order_id: index + 1)
    end
  end

  def calculate
    described_class.new(
      user:,
      context:,
      return_cash_transaction: return_transaction,
      reference_date:
    ).call
  end

  it "places the pending return on the first balance point that turns negative without it" do
    build_balance_timeline([
                             [ Date.new(2026, 11, 5), 6_000 ],
                             [ Date.new(2026, 11, 12), -1_500 ],
                             [ Date.new(2026, 11, 20), 2_000 ]
                           ])

    expect(calculate).to eq(Date.new(2026, 11, 12))
  end

  it "keeps the scheduled date when the balance never turns negative without the pending return" do
    build_balance_timeline([
                             [ Date.new(2026, 11, 5), 6_000 ],
                             [ Date.new(2026, 11, 12), -500 ],
                             [ Date.new(2026, 11, 20), 2_000 ]
                           ])

    expect(calculate).to eq(Date.new(2026, 12, 1))
  end

  it "places the pending return today when the balance already turned negative" do
    build_balance_timeline([
                             [ Date.new(2026, 11, 5), 6_000 ],
                             [ Date.new(2026, 11, 10), -1_500 ],
                             [ Date.new(2026, 11, 20), 2_000 ]
                           ])

    expect(calculate).to eq(reference_date)
  end

  it "never proposes a date in the past" do
    build_balance_timeline([
                             [ Date.new(2026, 10, 5), 6_000 ],
                             [ Date.new(2026, 10, 12), -9_000 ],
                             [ Date.new(2026, 11, 20), 2_000 ]
                           ])

    expect(calculate).to be >= reference_date
  end

  it "ignores balance points that already belong to the past" do
    build_balance_timeline([
                             [ Date.new(2026, 10, 5), 6_000 ],
                             [ Date.new(2026, 10, 12), -9_000 ],
                             [ Date.new(2026, 11, 20), 2_000 ]
                           ])

    expect(calculate).to eq(Date.new(2026, 11, 20))
  end

  it "returns nil when the return has no unpaid installment left" do
    return_transaction.cash_installments.update_all(paid: true)

    expect(calculate).to be_nil
  end
end
