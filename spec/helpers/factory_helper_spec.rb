# frozen_string_literal: true

require "rails_helper"

RSpec.describe FactoryHelper do
  subject(:helper) { Object.new.extend(described_class) }

  describe "#custom_create" do
    it "reuses the lowest-id associated record deterministically" do
      user = create(:user)
      create(:user_bank_account, :random, id: -30_001, user:)
      earlier = create(:user_bank_account, :random, id: -30_002, user:)

      expect(helper.custom_create(:user_bank_account, reference: { user: })).to eq(earlier)
    end
  end

  describe "#custom_create_polymorphic" do
    it "uses the first explicitly ordered model family" do
      allow(helper).to receive(:custom_create).and_return(:created)

      result = helper.custom_create_polymorphic(%i[cash_transaction card_transaction], reference: { user: :owner }, traits: [ :random ], options: { paid: false })

      expect(result).to eq(:created)
      expect(helper).to have_received(:custom_create).with(:cash_transaction, reference: { user: :owner }, traits: [ :random ], options: { paid: false })
    end
  end

  describe "financial factory graph contracts" do
    it "keeps the default card transaction limited to its required installment" do
      transaction = create(:card_transaction)

      expect(transaction.card_installments.size).to eq(1)
      expect(transaction.category_transactions).to be_empty
      expect(transaction.entity_transactions).to be_empty
    end

    it "creates card allocations only through the explicit trait" do
      transaction = create(:card_transaction, :with_allocations)

      expect(transaction.card_installments.size).to eq(1)
      expect(transaction.category_transactions.size).to eq(1)
      expect(transaction.entity_transactions.size).to eq(1)
    end
  end
end
