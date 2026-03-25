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

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

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

    it "persists card transaction ref month year based on the selected card cycle" do
      user_card.update!(due_date_day: 10, days_until_due_date: 5)

      post subscriptions_path, params: {
        subscription: {
          description: "Spotify",
          status: :active,
          user_id: user.id,
          card_transactions_attributes: {
            "0" => { date: Date.new(2026, 3, 6), price: -5500, user_card_id: user_card.id }
          }
        }
      }, headers: turbo_stream_headers

      card_transaction = Subscription.last.card_transactions.first

      expect(card_transaction.date.to_date).to eq(Date.new(2026, 3, 6))
      expect(card_transaction.month).to eq(4)
      expect(card_transaction.year).to eq(2026)
    end

    it "respects an explicit card ref month year override" do
      user_card.update!(due_date_day: 10, days_until_due_date: 5)

      post subscriptions_path, params: {
        subscription: {
          description: "Spotify",
          status: :active,
          user_id: user.id,
          card_transactions_attributes: {
            "0" => { date: Date.new(2026, 3, 6), month: 3, year: 2026, price: -5500, user_card_id: user_card.id }
          }
        }
      }, headers: turbo_stream_headers

      card_transaction = Subscription.last.card_transactions.first

      expect(card_transaction.month).to eq(3)
      expect(card_transaction.year).to eq(2026)
      expect(card_transaction.card_installments.first.month).to eq(3)
      expect(card_transaction.card_installments.first.year).to eq(2026)
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
      expect(subscription.cash_transactions.first.cash_installments.first.price).to eq(-5900)
      expect(subscription.card_transactions.reload.count).to eq(1)
      expect(subscription.card_transactions.first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(subscription.card_transactions.first.card_installments.first.price).to eq(-6100)
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

    it "does not destroy the record when it still has linked transactions" do
      subscription = create(:subscription, user:)
      create(:cash_transaction, user:, user_bank_account:, subscription:)

      expect do
        delete subscription_path(subscription), headers: turbo_stream_headers
      end.not_to change(Subscription, :count)
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_subscription = create(
        :subscription,
        user:,
        context: user.main_context,
        description: "Main isolated subscription",
        comment: "Main comment"
      )
      main_subscription.categories << category
      main_subscription.entities << entity

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Subscription Isolation"
      ).call
      derived_subscription = derived_context.subscriptions.find_by!(description: main_subscription.description)

      switch_to_context!(derived_context)

      expect do
        post subscriptions_path, params: {
          subscription: {
            description: "Derived only subscription",
            comment: "Derived plan",
            status: :active,
            user_id: user.id,
            category_id: category.id,
            entity_id: entity.id,
            cash_transactions_attributes: {
              "0" => { date: Date.new(2026, 4, 14), price: -4900, user_bank_account_id: user_bank_account.id }
            },
            card_transactions_attributes: {
              "0" => { date: Date.new(2026, 4, 15), price: -5500, user_card_id: user_card.id }
            }
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.subscriptions.reload.count }.by(1)
                                                                  .and change { user.main_context.subscriptions.reload.count }.by(0)

      patch subscription_path(derived_subscription), params: {
        subscription: {
          description: "Derived updated subscription",
          comment: derived_subscription.comment,
          status: derived_subscription.status,
          user_id: user.id,
          category_id: category.id,
          entity_id: entity.id,
          cash_transactions_attributes: {},
          card_transactions_attributes: {}
        }
      }, headers: turbo_stream_headers

      expect(derived_subscription.reload.description).to eq("Derived updated subscription")
      expect(main_subscription.reload.description).to eq("Main isolated subscription")

      expect do
        delete subscription_path(derived_subscription), headers: turbo_stream_headers
      end.to change { derived_context.subscriptions.reload.count }.by(-1)
                                                                  .and change { user.main_context.subscriptions.reload.count }.by(0)

      expect(Subscription.exists?(main_subscription.id)).to be(true)
    end
  end

  describe "[ subscription cascade context isolation ]" do
    it "keeps complex child transaction cascades inside the derived context" do
      main_subscription = create(
        :subscription,
        user:,
        context: user.main_context,
        description: "Main cascade subscription",
        comment: "Main comment"
      )
      main_subscription.categories << category
      main_subscription.entities << entity

      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        subscription: main_subscription,
        description: main_subscription.description,
        comment: main_subscription.comment,
        date: Date.new(2026, 3, 10),
        price: -4_900
      )
      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        subscription: main_subscription,
        description: main_subscription.description,
        comment: main_subscription.comment,
        date: Date.new(2026, 3, 15),
        price: -5_500
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Subscription Cascade Isolation"
      ).call
      derived_subscription = derived_context.subscriptions.find_by!(description: main_subscription.description)
      derived_cash_transaction = derived_subscription.cash_transactions.first
      derived_card_transaction = derived_subscription.card_transactions.first

      switch_to_context!(derived_context)

      patch subscription_path(derived_subscription), params: {
        subscription: {
          description: "Derived cascade subscription",
          comment: "Derived comment",
          status: :paused,
          user_id: user.id,
          category_id: category.id,
          entity_id: entity.id,
          cash_transactions_attributes: {
            "0" => {
              id: derived_cash_transaction.id,
              date: Date.new(2026, 4, 10),
              price: -6_100,
              user_bank_account_id: user_bank_account.id
            },
            "1" => {
              date: Date.new(2026, 4, 12),
              price: -1_700,
              user_bank_account_id: user_bank_account.id
            }
          },
          card_transactions_attributes: {
            "0" => { id: derived_card_transaction.id, _destroy: "1" },
            "1" => {
              date: Date.new(2026, 4, 18),
              price: -7_300,
              user_card_id: user_card.id
            }
          }
        }
      }, headers: turbo_stream_headers

      derived_subscription.reload
      main_subscription.reload

      expect(derived_subscription.description).to eq("Derived cascade subscription")
      expect(derived_subscription.comment).to eq("Derived comment")
      expect(derived_subscription).to be_paused
      expect(derived_subscription.cash_transactions.reload.count).to eq(2)
      expect(derived_subscription.card_transactions.reload.count).to eq(1)
      expect(derived_subscription.cash_transactions.pluck(:description).uniq).to eq([ "Derived cascade subscription" ])
      expect(derived_subscription.card_transactions.pluck(:description).uniq).to eq([ "Derived cascade subscription" ])
      expect(derived_subscription.cash_transactions.order(:date).pluck(:price)).to eq([ -6_100, -1_700 ])
      expect(derived_subscription.card_transactions.first.price).to eq(-7_300)
      expect(CardTransaction.exists?(derived_card_transaction.id)).to be(false)

      expect(main_subscription.description).to eq("Main cascade subscription")
      expect(main_subscription.comment).to eq("Main comment")
      expect(main_subscription).to be_active
      expect(main_subscription.cash_transactions.reload.count).to eq(1)
      expect(main_subscription.card_transactions.reload.count).to eq(1)
      expect(main_cash_transaction.reload.price).to eq(-4_900)
      expect(main_card_transaction.reload.price).to eq(-5_500)
      expect(main_subscription.cash_transactions.first.description).to eq("Main cascade subscription")
      expect(main_subscription.card_transactions.first.description).to eq("Main cascade subscription")
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context subscription while in a derived context" do
      main_subscription = create(
        :subscription,
        user:,
        context: user.main_context,
        description: "Main inaccessible subscription"
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Subscription Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get edit_subscription_path(main_subscription)
      expect(response).to have_http_status(:not_found)

      patch subscription_path(main_subscription), params: {
        subscription: {
          description: "Should not update",
          comment: main_subscription.comment,
          status: main_subscription.status,
          user_id: user.id,
          category_id: category.id,
          entity_id: entity.id,
          cash_transactions_attributes: {},
          card_transactions_attributes: {}
        }
      }, headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)

      delete subscription_path(main_subscription), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
