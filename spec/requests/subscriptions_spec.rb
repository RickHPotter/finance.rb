# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get subscriptions_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a subscription with linked cash and card transactions" do
      expect do
        post subscriptions_path, params: {
          subscription: {
            description: "Netflix",
            comment: "Family plan",
            status: :active,
            user_id: user.id,
            category_id: category.id,
            entity_id: entity.id,
            cash_transactions_attributes: {
              "0" => { date: Date.new(2026, 3, 14), price: -4900, user_bank_account_id: user_bank_account.id }
            },
            card_transactions_attributes: {
              "0" => { date: Date.new(2026, 3, 15), price: -5500, user_card_id: user_card.id }
            }
          }
        }, headers: turbo_stream_headers
      end.to change(Subscription, :count).by(1)
                                         .and change(CashTransaction, :count).by(2)
                                                                             .and change(CardTransaction, :count).by(1)

      subscription = Subscription.last

      expect(subscription.categories).to include(category)
      expect(subscription.entities).to include(entity)
      expect(subscription.cash_transactions.count).to eq(1)
      expect(subscription.cash_transactions.first.description).to eq("Netflix")
      expect(subscription.card_transactions.first.categories.pluck(:category_name)).to include(category.category_name, "SUBSCRIPTION")
      expect(subscription.reload.price).to eq(-10_400)
    end

    it "rejects linked card transactions without a card" do
      expect do
        post subscriptions_path, params: {
          subscription: {
            description: "Netflix",
            status: :active,
            user_id: user.id,
            card_transactions_attributes: {
              "0" => { date: Date.new(2026, 3, 15), price: -5500 }
            }
          }
        }, headers: turbo_stream_headers
      end.not_to change(Subscription, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "[ #update ]" do
    it "updates the subscription and manages linked transactions from the same form" do
      subscription = create(:subscription, user:, description: "Netflix", comment: "Family plan")
      subscription.categories << category
      subscription.entities << entity

      cash_transaction = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        subscription:,
        description: subscription.description,
        comment: subscription.comment,
        date: Date.new(2026, 3, 14),
        price: -4900
      )
      card_transaction = create(
        :card_transaction,
        user:,
        user_card:,
        subscription:,
        description: subscription.description,
        comment: subscription.comment,
        date: Date.new(2026, 3, 15),
        price: -5500
      )

      patch subscription_path(subscription), params: {
        subscription: {
          description: "Netflix Premium",
          comment: "Updated plan",
          status: :paused,
          user_id: user.id,
          category_id: category.id,
          entity_id: entity.id,
          cash_transactions_attributes: {
            "0" => { id: cash_transaction.id, date: cash_transaction.date, price: -5900, user_bank_account_id: user_bank_account.id }
          },
          card_transactions_attributes: {
            "0" => { id: card_transaction.id, _destroy: "1" },
            "1" => { date: Date.new(2026, 3, 20), price: -6100, user_card_id: user_card.id }
          }
        }
      }, headers: turbo_stream_headers

      subscription.reload

      expect(subscription.description).to eq("Netflix Premium")
      expect(subscription.comment).to eq("Updated plan")
      expect(subscription).to be_paused
      expect(subscription.cash_transactions.first.description).to eq("Netflix Premium")
      expect(subscription.cash_transactions.first.price).to eq(-5900)
      expect(subscription.card_transactions.reload.count).to eq(1)
      expect(subscription.card_transactions.first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(CardTransaction.exists?(card_transaction.id)).to be_falsey
      expect(subscription.price).to eq(-12_000)
    end
  end

  describe "[ #destroy ]" do
    it "destroys the record" do
      subscription = create(:subscription, user:)

      expect do
        delete subscription_path(subscription), headers: turbo_stream_headers
      end.to change(Subscription, :count).by(-1)
    end
  end
end
