# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasSubscription, type: :model do
  describe "[ concern behaviour ]" do
    let(:user) { create(:user, :random) }
    let(:subscription) { create(:subscription, user:) }
    let(:other_subscription) { create(:subscription, user:) }

    it "refreshes cached price when a cash transaction is created, moved, and destroyed" do
      cash_transaction = create(:cash_transaction, :random, user:, price: 200, subscription:)

      expect(subscription.reload.price).to eq(200)

      cash_transaction.update!(subscription: other_subscription)

      expect(subscription.reload.price).to eq(0)
      expect(other_subscription.reload.price).to eq(200)

      cash_transaction.destroy!

      expect(other_subscription.reload.price).to eq(0)
    end

    it "refreshes cached price when a card transaction changes price" do
      card_transaction = create(:card_transaction, :random, user:, price: -300, subscription:)

      expect(subscription.reload.price).to eq(-300)

      card_transaction.update!(price: -500)

      expect(subscription.reload.price).to eq(-500)
    end
  end
end
