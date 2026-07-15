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
end
