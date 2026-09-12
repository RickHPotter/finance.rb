# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledgers::Presenters::ExternalRow, type: :service do
  it "copies only immutable allowlisted scalar values from the financial models" do
    user = create(:user, :random)
    entity = create(:entity, user:)
    account = create(:user_bank_account, :random, user:, bank: create(:bank, :random))
    category = user.categories.find_by(category_name: "EXCHANGE RETURN") || create(:category, :random, user:, category_name: "EXCHANGE RETURN")
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "SAFE DESCRIPTION",
      comment: "PRIVATE COMMENT",
      date: Time.zone.local(2026, 9, 10, 12),
      month: 9,
      year: 2026,
      price: -2500,
      cash_installments: [],
      category_transactions_attributes: [ { category_id: category.id } ],
      entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
      cash_installments_attributes: [
        { number: 1, date: Time.zone.local(2026, 9, 10, 12), month: 9, year: 2026, price: -2500, paid: false }
      ]
    )
    share = Ledgers::Shares::Create.call(entity:, context: user.main_context).share

    row = described_class.build(installment: transaction.cash_installments.first, kind: :cash, share:)

    expect(row).to have_attributes(
      kind: :cash,
      description: "SAFE DESCRIPTION",
      number: 1,
      installments_count: 1,
      amount: -2500,
      paid: false,
      internal?: false
    )
    expect(row.instance_variables.map { |name| row.instance_variable_get(name) }).to all(satisfy { |value| !value.is_a?(ApplicationRecord) })
    expect(row.instance_variables).to contain_exactly(:@key, :@kind, :@description, :@date, :@number, :@installments_count, :@amount, :@paid)
    expect(row.key).to match(/\Aledger_row_[0-9a-f]{20}\z/)
    expect(row).not_to respond_to(:comment, :user_bank_account, :transaction)
  end
end
