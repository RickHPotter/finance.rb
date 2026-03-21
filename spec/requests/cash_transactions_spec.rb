# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashTransactions", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:subscription) { create(:subscription, user:) }

  let(:cash_transaction) do
    Params::CashTransactions.new(
      cash_transaction: {
        description: "Salary payment",
        price: 20_000,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        user_id: user.id,
        user_bank_account_id: user_bank_account.id,
        subscription_id: subscription.id
      },
      cash_installments: { count: 1 },
      category_transactions: [ { category_id: category.id } ],
      entity_transactions: [ {
        entity_id: entity.id,
        price: 0,
        price_to_be_returned: 0,
        exchanges_attributes: []
      } ]
    )
  end

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a cash transaction with installments, categories, and entities" do
      expect { post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers }.to change(CashTransaction, :count).by(1)

      created_cash_transaction = CashTransaction.last

      expect(created_cash_transaction.description).to eq("Salary payment")
      expect(created_cash_transaction.subscription).to eq(subscription)
      expect(created_cash_transaction.cash_installments.count).to eq(1)
      expect(created_cash_transaction.categories).to include(category)
      expect(created_cash_transaction.entities).to include(entity)
      expect(subscription.reload.price).to eq(20_000)
    end

    it "passes reimbursement intent through to exchange notifications with the correct payload shape" do
      other_user = create(:user, :random)
      create(:entity, user:, entity_name: "OTHER USER", entity_user: other_user)
      other_user_entity = create(:entity, user: other_user, entity_name: "ME", entity_user: user)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end

      cash_transaction.category_transactions = [ { category_id: user.built_in_category("EXCHANGE").id } ]
      cash_transaction.entity_transactions = [ {
        entity_id: user.entities.that_are_users.find_by(entity_user: other_user).id,
        price: -20_000,
        price_to_be_returned: -20_000,
        exchanges_attributes: [
          { price: -20_000, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year }
        ]
      } ]
      cash_transaction.friend_notification_intent = "reimbursement"

      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include(
        "version" => "cash_exchange_v2",
        "intent" => "reimbursement",
        "category_ids" => other_user.built_in_category("BORROW RETURN").id,
        "entity_ids" => other_user_entity.id
      )
      expect(headers.fetch("cash_installments_attributes")).to contain_exactly(
        a_hash_including("price" => 20_000)
      )
      expect(headers.fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => false,
          "price" => 0,
          "price_to_be_returned" => 0,
          "entity_id" => other_user_entity.id,
          "exchanges_count" => 0
        )
      )
    end

    it "defaults pure exchange notifications to loan intent" do
      other_user = create(:user, :random)
      create(:entity, user:, entity_name: "OTHER USER", entity_user: other_user)
      other_user_entity = create(:entity, user: other_user, entity_name: "ME", entity_user: user)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end

      cash_transaction.category_transactions = [ { category_id: user.built_in_category("EXCHANGE").id } ]
      cash_transaction.entity_transactions = [ {
        entity_id: user.entities.that_are_users.find_by(entity_user: other_user).id,
        price: -20_000,
        price_to_be_returned: -20_000,
        exchanges_attributes: [
          { price: -20_000, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year }
        ]
      } ]

      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include(
        "version" => "cash_exchange_v2",
        "intent" => "loan",
        "category_ids" => other_user.built_in_category("EXCHANGE").id
      )
      expect(headers.fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => true,
          "price" => 20_000,
          "price_to_be_returned" => 20_000,
          "entity_id" => other_user_entity.id,
          "exchanges_count" => 1
        )
      )
    end
  end

  describe "[ #update ]" do
    before do
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      @existing_cash_transaction = CashTransaction.last
    end

    it "updates the record and its installment price" do
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { price: 35_000, description: "Updated salary" })
      cash_transaction.cash_installments.first[:price] = 35_000

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      @existing_cash_transaction.reload

      expect(@existing_cash_transaction.description).to eq("Updated salary")
      expect(@existing_cash_transaction.price).to eq(35_000)
      expect(@existing_cash_transaction.cash_installments.first.price).to eq(35_000)
      expect(subscription.reload.price).to eq(35_000)
    end

    it "updates the linked subscription" do
      other_subscription = create(:subscription, user:)
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { subscription_id: other_subscription.id })

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      expect(@existing_cash_transaction.reload.subscription).to eq(other_subscription)
      expect(subscription.reload.price).to eq(0)
      expect(other_subscription.reload.price).to eq(20_000)
    end
  end

  describe "[ #destroy ]" do
    before do
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      @existing_cash_transaction = CashTransaction.last
    end

    it "destroys the record and its installments" do
      cash_installment_ids = @existing_cash_transaction.cash_installments.ids

      expect { delete cash_transaction_path(@existing_cash_transaction), headers: turbo_stream_headers }.to change(CashTransaction, :count).by(-1)

      expect(CashInstallment.where(id: cash_installment_ids)).to be_empty
    end
  end

  describe "[ #month_year ]" do
    it "responds successfully for an existing month_year" do
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      month_year = Time.zone.today.strftime("%Y%m")

      get month_year_cash_transactions_path, params: {
        month_year:,
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
  end
end
