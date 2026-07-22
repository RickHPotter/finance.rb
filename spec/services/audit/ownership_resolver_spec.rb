# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::OwnershipResolver do
  let(:owner_id) { 41 }
  let(:context_id) { 73 }
  let(:cash_transaction) { CashTransaction.new(user_id: owner_id, context_id:) }
  let(:card_transaction) { CardTransaction.new(user_id: owner_id, context_id:) }

  def expect_ownership(record, expected_context_id: context_id)
    expect(described_class.resolve!(record)).to eq(
      described_class::Ownership.new(owner_id:, context_id: expected_context_id)
    )
  end

  it "resolves direct context-owned models" do
    records = [
      cash_transaction,
      card_transaction,
      Budget.new(user_id: owner_id, context_id:),
      Subscription.new(user_id: owner_id, context_id:),
      Investment.new(user_id: owner_id, context_id:)
    ]

    records.each { |record| expect_ownership(record) }
  end

  it "resolves user cards and bank accounts without a record context" do
    expect_ownership(UserCard.new(user_id: owner_id), expected_context_id: nil)
    expect_ownership(UserBankAccount.new(user_id: owner_id), expected_context_id: nil)
  end

  it "inherits installment ownership from its transaction" do
    expect_ownership(CashInstallment.new(cash_transaction:))
    expect_ownership(CardInstallment.new(card_transaction:))
  end

  it "inherits allocation and exchange ownership through their transactable" do
    expect_ownership(CategoryTransaction.new(transactable: cash_transaction))

    entity_transaction = EntityTransaction.new(transactable: card_transaction)
    expect_ownership(entity_transaction)
    expect_ownership(Exchange.new(entity_transaction:))
  end

  it "resolves reference ownership through its user card" do
    reference = Reference.new(user_card: UserCard.new(user_id: owner_id), context_id:)

    expect_ownership(reference)
  end

  it "uses the Piggy Bank source and falls back to its return transaction" do
    expect_ownership(PiggyBank.new(source_cash_transaction: cash_transaction))
    expect_ownership(PiggyBank.new(return_cash_transaction: cash_transaction))
  end

  it "fails closed for ownerless and unsupported records" do
    expect { described_class.resolve!(UserBankAccount.new) }.to raise_error(described_class::UnresolvableOwnershipError)
    expect { described_class.resolve!(User.new) }.to raise_error(described_class::UnsupportedRecordError)
  end
end
