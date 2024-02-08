# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardTransactions", type: :request do
  let!(:user) { create(:user) }
  let!(:card_transaction) { create(:card_transaction, :random) }
  let!(:valid_attributes) do
    {
      card_transaction: {
        ct_description: "Newly Added CardTransaction",
        price: 200.0,
        user_id: card_transaction.user_id,
        user_card_id: card_transaction.user_card_id,
        date: card_transaction.date,
        installments_attributes: build_list(:installment, 2, price: 100.0).map(&:attributes),
        category_transactions_attributes: build_list(:category_transaction, 1, :random).map(&:attributes),
        entity_transactions_attributes: build_list(:entity_transaction, 1, :random).map(&:attributes).push(
          exchanges_attributes: []
        )
      }
    }
  end
  let!(:actions) do
    {
      index: card_transactions_path,
      new: new_card_transaction_path,
      edit: edit_card_transaction_path(card_transaction)
    }
  end

  shared_examples "redirects to sign-in page" do |action|
    it "redirects to sign-in page on request to ##{action}" do
      get actions[action]

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "[ GET card_transaction* ]" do
    context "(when not logged in)" do
      %i[index new edit].each do |action|
        it_behaves_like "redirects to sign-in page", action
      end
    end

    context "( when logged in )" do
      before { sign_in user }

      %i[index new edit].each do |action|
        it "succeeds on request to ##{action}" do
          get actions[action]

          expect(response).to have_http_status(:success)
        end
      end

      it "succeeds on request to #destroy" do
        expect { delete card_transaction_path(card_transaction) }.to change(CardTransaction, :count)
      end

      context "( on #create )" do
        it "creates a new record on request to #create / without paying entities" do
          valid_attributes[:card_transaction][:entity_transactions_attributes][0]["is_payer"] = false

          expect { post card_transactions_path, params: valid_attributes }.to change(CardTransaction, :count).by(1)
          expect(response.body).to include(CardTransaction.last.ct_description)

          new_card_transaction = CardTransaction.last

          expect(new_card_transaction.installments).to be_present
          expect(new_card_transaction.category_transactions).to be_present
          expect(new_card_transaction.entity_transactions).to be_present

          expect(new_card_transaction.category_transactions.map(&:category).pluck(:category_name)).to_not include("Exchange")
        end

        it "creates a new record on request to #create / with paying entities" do
          entity_transaction = valid_attributes[:card_transaction][:entity_transactions_attributes][0]
          entity_transaction["is_payer"] = true
          # entity_transaction["exchanges_attributes"] =
          #   build(:exchange, :random, exchange_type: :monetary, price: entity_transaction["price"]).map(&:attributes)

          expect { post card_transactions_path, params: valid_attributes }.to change(CardTransaction, :count).by(1)
          expect(response.body).to include(CardTransaction.last.ct_description)

          new_card_transaction = CardTransaction.last

          expect(new_card_transaction.installments).to be_present
          expect(new_card_transaction.category_transactions).to be_present
          expect(new_card_transaction.entity_transactions).to be_present

          expect(new_card_transaction.category_transactions.map(&:category).pluck(:category_name)).to include("Exchange")

          # exchanges = card_transaction.entity_transactions.where(is_payer: true).map(&:exchanges)
          # expect(exchanges).to_be present
        end
      end

      context "( on #update )" do
        it "updates the record to include paying entities" do
          entity_transaction = valid_attributes[:card_transaction][:entity_transactions_attributes][0]
          entity_transaction["is_payer"] = true
          # entity_transaction["exchanges_attributes"] =
          #   build(:exchange, :random, exchange_type: :monetary, price: entity_transaction["price"]).map(&:attributes)

          patch(card_transaction_path(card_transaction), params: valid_attributes)
          card_transaction.reload

          expect(card_transaction.paying_entities).to be_present
          expect(card_transaction.category_transactions.map(&:category).pluck(:category_name)).to include("Exchange")

          # exchanges = card_transaction.entity_transactions.where(is_payer: true).map(&:exchanges)
          # expect(exchanges).to_be present
        end

        it "updates the record to exclude paying entities" do
          valid_attributes[:card_transaction][:entity_transactions_attributes][0]["is_payer"] = false

          patch(card_transaction_path(card_transaction), params: valid_attributes)
          card_transaction.reload

          expect(card_transaction.paying_entities).to be_empty
          expect(card_transaction.category_transactions.map(&:category).pluck(:category_name)).to_not include("Exchange")

          # exchanges = card_transaction.entity_transactions.where(is_payer: true).map(&:exchanges)
          # expect(exchanges).to_be empty
        end

        # FIXME: include entity_transaction.status regarding exchange.exchange_type change
        it "updates the record to change the exchange_type to :non_monetary" do
          # expect(exchange.money_transaction).to be(nil)
          # expect(exchange.entity_transaction.finished?).to be(true)
          #
          # exchange.monetary!
          # expect(exchange.money_transaction).to_not be(nil)
          # expect(exchange.entity_transaction.pending?).to be(true)
        end

        it "updates the record to change the exchange_type to :monetary" do
          # expect(exchange.money_transaction).to_not be(nil)
          #
          # exchange.non_monetary!
          # expect(exchange.money_transaction).to be(nil)
        end

        it "updates the record to change the exchange_type to :monetary" do
        end
      end

      context "( money_transaction creation by default due to monetary exchange )" do
        it "generates a money_transaction" do
          # expect(exchange.money_transaction).to_not be(nil)
        end
      end
    end
  end
end
