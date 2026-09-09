# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::MovementClassifier do
  subject(:classifier) { described_class.new }

  let(:user) { create(:user, :random) }

  it "preserves ordinary, generated, failed, transfer, and piggy-bank precedence" do
    ordinary = build_transaction
    generated_payment = build_transaction(cash_transaction_type: "CardInstallment", categories: [ category("FAILED LEND/BORROW RETURN") ])
    failed = build_transaction(categories: [ category("FAILED LEND/BORROW RETURN"), category("EXCHANGE RETURN") ])
    transfer = build_transaction(categories: [ category("EXCHANGE") ])
    piggy_bank = build_transaction(cash_transaction_type: "PiggyBank", categories: [ category("PIGGY BANK") ])
    investment = build_transaction(cash_transaction_type: "Investment")

    expect(
      [ ordinary, generated_payment, failed, transfer, piggy_bank, investment ].map { |transaction| classifier.call(transaction) }
    ).to eq(%i[ordinary generated_card_payment failed_transfer transfer piggy_bank generated_investment])
  end

  it "classifies card transactions through their allocations without cash subtype assumptions" do
    card_transaction = CardTransaction.new
    card_transaction.categories << category("BORROW RETURN")

    expect(classifier.call(card_transaction)).to eq(:transfer)
  end

  private

  def build_transaction(cash_transaction_type: nil, categories: [])
    CashTransaction.new(cash_transaction_type:).tap do |transaction|
      categories.each { |record| transaction.categories << record }
    end
  end

  def category(name)
    Category.new(user:, category_name: name)
  end
end
