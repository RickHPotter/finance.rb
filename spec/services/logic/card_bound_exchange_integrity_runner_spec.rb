# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CardBoundExchangeIntegrityRunner do
  describe "#call" do
    it "rebuilds one shared card-bound exchange return projection for an orphaned family" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner card-bound orphan",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))

      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity: receiver_entity, price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      second_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000,
                                          date: Date.new(2026, 4, 12), month: 4, year: 2026)

      original_projection = first_exchange.cash_transaction
      Exchange.where(id: [ first_exchange.id, second_exchange.id ]).update_all(cash_transaction_id: nil)
      original_projection.cash_installments.delete_all
      original_projection.delete

      result = described_class.new(ids: [ first_exchange.id, second_exchange.id ], dry_run: false).call
      rebuilt_projection = Exchange.find(first_exchange.id).cash_transaction

      expect(result[:updated_count]).to eq(1)
      expect(rebuilt_projection).to be_present
      expect(Exchange.find(first_exchange.id).cash_transaction_id).to eq(rebuilt_projection.id)
      expect(Exchange.find(second_exchange.id).cash_transaction_id).to eq(rebuilt_projection.id)
      expect(rebuilt_projection.price).to eq(-2_000)
      expect(rebuilt_projection.cash_installments.count).to eq(1)
      expect(rebuilt_projection.cash_installments.first.price).to eq(-2_000)
      expect(rebuilt_projection.cash_installments.first.date.to_date).to eq(Date.new(2026, 4, 10))
    end

    it "rebuilds one shared projection for many entity transactions in the same card-bound bucket" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      first_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner shared bucket one",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      first_card_transaction.category_transactions.destroy_all
      first_card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      first_entity_transaction = first_card_transaction.entity_transactions.first
      first_entity_transaction.update!(entity: receiver_entity, price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 1)
      first_exchange = create(:exchange, entity_transaction: first_entity_transaction, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -2_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)

      second_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner shared bucket two",
        date: Date.new(2026, 3, 12),
        month: 4,
        year: 2026,
        price: -500
      )
      second_card_transaction.category_transactions.destroy_all
      second_card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      second_entity_transaction = second_card_transaction.entity_transactions.first
      second_entity_transaction.update!(entity: receiver_entity, price: -500, price_to_be_returned: -500, is_payer: true, exchanges_count: 1)
      second_exchange = create(:exchange, entity_transaction: second_entity_transaction, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -500,
                                          date: Date.new(2026, 4, 12), month: 4, year: 2026)

      first_projection = first_exchange.cash_transaction
      second_projection = second_exchange.cash_transaction
      Exchange.where(id: [ first_exchange.id, second_exchange.id ]).update_all(cash_transaction_id: nil)
      first_projection.cash_installments.delete_all
      second_projection.cash_installments.delete_all
      first_projection.delete
      second_projection.delete

      result = described_class.new(ids: [ first_exchange.id, second_exchange.id ], dry_run: false).call
      rebuilt_projection = Exchange.find(first_exchange.id).cash_transaction

      expect(result[:updated_count]).to eq(1)
      expect(Exchange.find(second_exchange.id).cash_transaction_id).to eq(rebuilt_projection.id)
      expect(rebuilt_projection.exchanges.count).to eq(2)
      expect(rebuilt_projection.price).to eq(-2_500)
      expect(rebuilt_projection.cash_installments.first.price).to eq(-2_500)
    end

    it "skips a family when the existing card-bound projection has paid history" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner paid projection skip",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -1_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))

      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity: receiver_entity, price: -1_000, price_to_be_returned: -1_000, is_payer: true, exchanges_count: 1)
      exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                   date: Date.new(2026, 4, 10), month: 4, year: 2026)

      projection = exchange.cash_transaction
      projection.cash_installments.first.update_columns(paid: true)
      projection.update_columns(paid: true)
      exchange.update_columns(cash_transaction_id: nil)

      result = described_class.new(ids: [ exchange.id ], dry_run: false).call

      expect(result[:updated_count]).to eq(0)
      expect(result[:skipped_count]).to eq(1)
      expect(result[:skipped].first[:reason]).to eq("existing_projection_paid_history")
    end
  end
end
