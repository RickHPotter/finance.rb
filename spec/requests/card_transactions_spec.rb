# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardTransactions", type: :request do
  let(:bank) { create(:bank, :random) }
  let(:user) { create(:user, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card_one) { create(:user_card, :random, user:, card:, user_card_name: "Gaara", current_due_date: Date.current) }
  let(:user_card_two) { create(:user_card, :random, user:, card:, user_card_name: "Jiraiya", current_due_date: Date.current) }
  let(:entity_one) { create(:entity, :random, user:) }
  let(:entity_two) { create(:entity, :random, user:) }

  let(:card_transaction) do
    Params::CardTransactions.new(
      card_transaction: { price: -20_000, date: Date.current, user_id: user.id, user_card_id: user_card_one.id },
      card_installments: { count: 1 }, category_transactions: [],
      entity_transactions: [ { entity_id: entity_one.id, price: -2200, exchanges_attributes: [ { price: -2200, exchange_type: :monetary } ] } ]
    )
  end

  def check_paying_entities(card_transaction)
    expect(card_transaction.paying_entities).to be_present
    expect(card_transaction.paying_transactions.flat_map(&:exchanges)).to be_present
    expect(card_transaction.built_in_categories_by(category_name: "EXCHANGE")).to be_present
  end

  def check_non_paying_entities(card_transaction)
    expect(card_transaction.non_paying_entities).to be_present
    expect(card_transaction.non_paying_transactions).to be_present
    expect(card_transaction.non_paying_transactions.flat_map(&:exchanges)).to be_empty
    expect(card_transaction.built_in_categories_by(category_name: "EXCHANGE")).to_not be_present
  end

  def check_card_installments(card_installments)
    installments_by_month_year = card_installments.group_by(&:month_year)

    installments_by_month_year.each_pair do |month_year, installments_collection|
      expect(installments_collection.pluck(:cash_transaction_id).uniq.count).to eq(1)
      expect(installments_collection.map(&:month_year).uniq).to eq([ month_year ])
      expect(installments_collection.sum(&:price)).to be >= installments_collection.first.cash_transaction.price
    end
  end

  def check_exchanges(exchanges)
    exchanges.each do |exchange|
      expect(exchange.cash_transaction.present?).to be(exchange.monetary?)
    end
  end

  before { sign_in user }

  # FIXME: failing idk why
  describe "[ #create ]" do
    it "creates one new record with one installment and non-paying entities" do
      card_transaction.entity_transactions = [ { entity_id: entity_one.id, price: -22.00, exchanges_attributes: [] } ]
      expect { post card_transactions_path, params: card_transaction.params }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      check_non_paying_entities(new_card_transaction)
      check_card_installments(new_card_transaction.card_installments)
    end

    it "creates one new record with two installments and two paying entities" do
      card_transaction.card_installments = { count: 2 }
      card_transaction.entity_transactions = [
        { entity_id: entity_one.id, price: -22.00, exchanges_attributes: [ { price: -22.00, exchange_type: :monetary } ] },
        { entity_id: entity_two.id, price: -22.00, exchanges_attributes: [ { price: -22.00, exchange_type: :monetary } ] }
      ]

      expect { post card_transactions_path, params: card_transaction.params }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      check_paying_entities(new_card_transaction)
      check_card_installments(new_card_transaction.card_installments)
    end

    it "creates two new records, each with two installments that overlap months, and two paying entities" do
      card_transaction.card_installments = { count: 2 }
      card_transaction.entity_transactions = [
        { entity_id: entity_one.id, price: -22.00, exchanges_attributes: [ { price: -22.00, exchange_type: :monetary } ] },
        { entity_id: entity_two.id, price: -22.00, exchanges_attributes: [ { price: -22.00, exchange_type: :monetary } ] }
      ]

      expect { post card_transactions_path, params: card_transaction.params }.to change(CardTransaction, :count).by(1)
      card_transaction_one = CardTransaction.last

      sign_in user

      card_transaction.date += 40.days # 1 month is sometimes not enough
      expect { post card_transactions_path, params: card_transaction.params }.to change(CardTransaction, :count).by(1)
      card_transaction_two = CardTransaction.last

      check_paying_entities(card_transaction_one)
      check_paying_entities(card_transaction_two)
      check_card_installments([ *card_transaction_one.card_installments, *card_transaction_two.card_installments ])
    end
  end

  describe "[ #update ]" do
    before do
      card_transaction.entity_transactions = [ { entity_id: entity_one.id, price: -22.00, exchanges_attributes: [] } ]
      post card_transactions_path, params: card_transaction.params
      @existing_card_transaction = CardTransaction.last

      sign_in user
    end

    it "updates the record to have a non_paying entity" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: false })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_non_paying_entities(@existing_card_transaction)
    end

    it "updates the record to have one paying entity" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_paying_entities(@existing_card_transaction)
    end

    it "updates the record to change the exchange_type to :non_monetary then to :monetary" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :non_monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)

      sign_in user

      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)
    end

    it "updates the record to change the exchange_type to :monetary then to :non_monetary" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)

      sign_in user

      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :non_monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)
    end

    it "updates the record accordingly given a change in the card_transaction FKs" do
      cash_transaction_one = @existing_card_transaction.card_installments.first.cash_transaction

      card_transaction.use_base(@existing_card_transaction, card_transaction_options: { user_card_id: user_card_two.id })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params)

      cash_transaction_two = @existing_card_transaction.card_installments.first.cash_transaction

      expect(cash_transaction_one).to_not eq cash_transaction_two
      expect(CashTransaction.exists?(cash_transaction_one.id)).to be_falsey
      expect(CashTransaction.exists?(cash_transaction_two.id)).to be_truthy
    end
  end

  describe "[ #destroy ]" do
    before do
      (1..3).each do |i|
        sign_in user
        card_transaction.description = i
        post card_transactions_path, params: card_transaction.params
      end
    end

    it "succeeds on request to #destroy" do
      card_transactions = CardTransaction.where(description: (1..3))

      card_transactions.each do |card_transaction_to_be_deleted|
        sign_in user
        expect { delete card_transaction_path(card_transaction_to_be_deleted) }.to change(CardTransaction, :count).by(-1)
        expect(card_transaction_to_be_deleted.card_installments).to_not be_present
        expect(card_transaction_to_be_deleted.entity_transactions).to_not be_present
      end
    end
  end
end
