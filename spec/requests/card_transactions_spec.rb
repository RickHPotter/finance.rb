# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardTransactions", type: :request do
  let!(:user) { create(:user) }

  let!(:built_card_transaction) { build(:card_transaction, :random, ct_description: "Newly Added CardTransaction") }
  let!(:built_card_transaction_attributes) do
    { card_transaction: {
      ct_description: built_card_transaction.ct_description,
      price: built_card_transaction.price,
      user_id: built_card_transaction.user_id,
      user_card_id: built_card_transaction.user_card_id,
      date: built_card_transaction.date,
      installments_attributes: built_card_transaction.installments.map(&:attributes),
      category_transactions_attributes: built_card_transaction.category_transactions.map(&:attributes),
      entity_transactions_attributes: built_card_transaction.entity_transactions.map(&:attributes)
    } }
  end

  let!(:card_transaction) { create(:card_transaction, :random, ct_description: "Existing CardTransaction") }
  let!(:existing_attributes) do
    { card_transaction: {
      ct_description: card_transaction.ct_description,
      price: card_transaction.price,
      user_id: card_transaction.user_id,
      user_card_id: card_transaction.user_card_id,
      date: card_transaction.date,
      installments_attributes: card_transaction.installments.map(&:attributes),
      category_transactions_attributes: card_transaction.category_transactions.map(&:attributes),
      entity_transactions_attributes: card_transaction.entity_transactions.map { |e| e.attributes.merge(exchanges_attributes: []) }
    } }
  end

  let!(:entity_transaction_ref) { -> { existing_attributes[:card_transaction][:entity_transactions_attributes].first } }
  let!(:exchange_ref) { -> { existing_attributes[:card_transaction][:entity_transactions_attributes].first[:exchanges_attributes]&.first } }

  def check_paying_entities(card_transaction)
    expect(card_transaction.paying_entities).to be_present
    expect(card_transaction.paying_transactions.flat_map(&:exchanges)).to be_present
    expect(card_transaction.built_in_categories_by(category_name: "Exchange")).to be_present
  end

  def check_non_paying_entities(card_transaction)
    expect(card_transaction.non_paying_entities).to be_present
    expect(card_transaction.non_paying_transactions).to be_present
    expect(card_transaction.non_paying_transactions.flat_map(&:exchanges)).to be_empty
    expect(card_transaction.built_in_categories_by(category_name: "Exchange")).to_not be_present
  end

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a new record on request to #create / without paying entities" do
      expect { post card_transactions_path, params: built_card_transaction_attributes }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      check_non_paying_entities(new_card_transaction)
    end

    it "creates a new record on request to #create / with paying entities" do
      entity_transaction = built_card_transaction.entity_transactions.first
      attributes = { "is_payer" => true, exchanges_attributes: build(:exchange, exchange_type: :monetary, entity_transaction:).attributes }
      new_entity_transaction = entity_transaction.attributes.merge(attributes)
      params = built_card_transaction_attributes
      params[:card_transaction][:entity_transactions_attributes] = [ new_entity_transaction ]

      expect { post card_transactions_path, params: }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      check_paying_entities(new_card_transaction)
    end
  end

  describe "[ #update ]" do
    before do
      card_transaction.save
    end

    it "updates the record to include a paying entity" do
      entity_transaction = card_transaction.entity_transactions.first
      params = { "is_payer" => true, exchanges_attributes: build(:exchange, exchange_type: :monetary, entity_transaction:).attributes }
      updated_entity_transaction = card_transaction.entity_transactions.first.attributes.merge(params)
      entity_transaction_ref.call.merge! updated_entity_transaction

      put(card_transaction_path(card_transaction), params: existing_attributes)

      check_paying_entities(card_transaction)
    end

    it "updates the record to include a non_paying entity" do
      updated_entity_transaction = card_transaction.entity_transactions.first.attributes.merge("is_payer" => false, exchanges_attributes: [])
      entity_transaction_ref.call.merge! updated_entity_transaction

      put(card_transaction_path(card_transaction), params: existing_attributes)

      check_non_paying_entities(card_transaction)
    end

    it "updates the record to modify current non_paying entity to paying entity" do
      entity_transaction = card_transaction.entity_transactions.first
      attributes = { "is_payer" => true, exchanges_attributes: build(:exchange, exchange_type: :monetary, entity_transaction:).attributes }
      updated_entity_transaction = entity_transaction.attributes.merge(attributes)
      entity_transaction_ref.call.merge! updated_entity_transaction

      put(card_transaction_path(card_transaction), params: existing_attributes)

      check_paying_entities(card_transaction)
    end

    it "updates the record to change the exchange_type to :non_monetary then to :monetary" do
      params = existing_attributes
      entity_transaction = params[:card_transaction][:entity_transactions_attributes].first
      entity_transaction[:exchanges_attributes] = build(:exchange, exchange_type: :non_monetary, entity_transaction_id: entity_transaction["id"]).attributes

      put(card_transaction_path(card_transaction), params:)
      card_transaction.reload

      exchange = card_transaction.entity_transactions.first.exchanges.first

      expect(exchange.money_transaction).to be(nil)
      expect(exchange.entity_transaction.finished?).to be(true)

      exchange.monetary!
      expect(exchange.money_transaction).to_not be(nil)
      expect(exchange.entity_transaction.pending?).to be(true)
    end

    it "updates the record to change the exchange_type to :monetary then to :non_monetary" do
      params = existing_attributes
      entity_transaction = params[:card_transaction][:entity_transactions_attributes].first
      entity_transaction.merge!("is_payer" => true)
      entity_transaction[:exchanges_attributes] = build(:exchange, exchange_type: :monetary, entity_transaction_id: entity_transaction["id"]).attributes

      put(card_transaction_path(card_transaction), params:)
      card_transaction.entity_transactions.reload

      exchange = card_transaction.entity_transactions.first.exchanges.first

      expect(exchange.money_transaction).to_not be(nil)
      expect(exchange.entity_transaction.pending?).to be(true)

      exchange.non_monetary!
      expect(exchange.money_transaction).to be(nil)
      expect(exchange.entity_transaction.finished?).to be(true)
    end
  end

  describe "[ #destroy ]" do
    it "succeeds on request to #destroy" do
      card_transaction.save

      expect { delete card_transaction_path(card_transaction) }.to change(CardTransaction, :count).by(-1)
    end
  end
end
