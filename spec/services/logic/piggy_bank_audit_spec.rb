# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::PiggyBankAudit do
  it "reports return projection drift and ignores healthy groups" do
    user = create(:user, :random)
    account = create(:user_bank_account, :random, user:)
    entity = create(:entity, :random, user:)

    build_source = lambda do |description|
      build(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: account,
        description:,
        price: -5_000,
        cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
        category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
        entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
        piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
      )
    end

    healthy_source = build_source.call("Healthy reserve")
    healthy_source.save!
    broken_source = build_source.call("Broken reserve")
    broken_source.save!
    broken_return = broken_source.piggy_bank.return_cash_transaction
    broken_return.update_columns(price: 4_000)

    rows = described_class.new(current_user: user, current_context: user.main_context).call

    expect(rows.map { |row| row[:id] }).to eq([ broken_return.id ])
    expect(rows.first[:issues]).to include("grouped_principal_drift")
    expect(rows.first).to include(principal: 5_000, expected_total: 5_000, recorded_total: 4_000)
  end
end
