# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityTransactable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }

  let(:entity_one) { create(:entity, :random, user:) }
  let(:entity_two) { create(:entity, :random, user:) }

  let(:card_transaction) do
    create(:card_transaction, :random, user:, user_card:, price: -600, entity_transactions: [
             build(:entity_transaction, :random, entity: entity_one, price: -200, price_to_be_returned: 0, transactable: nil),
             build(:entity_transaction, :random, entity: entity_two, price: -200, price_to_be_returned: -200, transactable: nil)
           ])
  end

  describe "[ public class methods ]" do
    it "#non_paying_transactions / #non_paying_entities" do
      expect(card_transaction.non_paying_transactions).to include(card_transaction.entity_transactions.first)
      expect(card_transaction.non_paying_entities).to include(entity_one)
    end

    it "#paying_transactions / #paying_entities" do
      expect(card_transaction.paying_transactions).to include(card_transaction.entity_transactions.second)
      expect(card_transaction.paying_entities).to include(entity_two)
    end
  end
end
