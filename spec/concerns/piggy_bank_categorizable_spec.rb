# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBankCategorizable do
  let(:user) { create(:user, :random) }

  def category_join(name, destroy: false)
    CategoryTransaction.new(category: user.built_in_category(name)).tap do |join|
      join.mark_for_destruction if destroy
    end
  end

  it "rejects exchange and Piggy Bank category families together" do
    transaction = build(:cash_transaction, user:, context: user.main_context)
    transaction.category_transactions = [ category_join("EXCHANGE"), category_join("PIGGY BANK") ]

    expect(transaction).not_to be_valid
    expect(transaction.errors.of_kind?(:base, :mixed_exchange_and_piggy_bank_categories)).to be(true)
  end

  it "rejects source and return categories from the same family" do
    transaction = build(:cash_transaction, user:, context: user.main_context)
    transaction.category_transactions = [ category_join("PIGGY BANK"), category_join("PIGGY BANK RETURN") ]

    expect(transaction).not_to be_valid
    expect(transaction.errors.of_kind?(:base, :mixed_piggy_bank_categories)).to be(true)
  end

  it "ignores category joins marked for destruction" do
    transaction = build(:cash_transaction, user:, context: user.main_context)
    transaction.category_transactions = [ category_join("EXCHANGE"), category_join("PIGGY BANK", destroy: true) ]

    transaction.valid?

    expect(transaction.errors.of_kind?(:base, :mixed_exchange_and_piggy_bank_categories)).to be(false)
  end

  it "rejects Piggy Bank categories on card transactions" do
    transaction = build(:card_transaction, user:, context: user.main_context)
    transaction.category_transactions = [ category_join("PIGGY BANK") ]

    expect(transaction).not_to be_valid
    expect(transaction.errors.of_kind?(:base, :piggy_bank_cash_only)).to be(true)
  end

  it "rejects manually creating a new cash transaction with Piggy Bank Return category" do
    transaction = build(:cash_transaction, user:, context: user.main_context)
    transaction.category_transactions = [ category_join("PIGGY BANK RETURN") ]

    expect(transaction).not_to be_valid
    expect(transaction.errors.of_kind?(:base, :piggy_bank_return_system_managed)).to be(true)
  end

  it "allows updating an existing generated Piggy Bank return without projection write bypass" do
    account = create(:user_bank_account, :random, user:)
    entity = create(:entity, :random, user:)
    source = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "Emergency reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
      category_transactions: [ category_join("PIGGY BANK") ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
    )

    generated_return = CashTransaction.find(source.piggy_bank.return_cash_transaction_id)
    generated_return.date = 4.months.from_now

    expect(generated_return).to be_valid
  end

  it "rejects removing the Piggy Bank Return category from an existing generated return" do
    account = create(:user_bank_account, :random, user:)
    entity = create(:entity, :random, user:)
    source = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "Emergency reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
      category_transactions: [ category_join("PIGGY BANK") ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
    )

    generated_return = CashTransaction.find(source.piggy_bank.return_cash_transaction_id)
    generated_return.category_transactions.to_a.first.mark_for_destruction

    expect(generated_return).not_to be_valid
    expect(generated_return.errors.of_kind?(:base, :piggy_bank_return_system_managed)).to be(true)
  end
end
