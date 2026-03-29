# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::StandaloneExchangeIntegrityRunner do
  describe "#call" do
    it "rebuilds standalone exchange return installments and keeps price aligned when it originally matched price_to_be_returned" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner drift",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))

      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity: receiver_entity, price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000,
                        date: Date.new(2026, 5, 10), month: 5, year: 2026)

      exchange_return = first_exchange.cash_transaction.reload
      exchange_return.cash_installments.delete_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -2_000, starting_price: -2_000,
                                                paid: false, cash_installments_count: 1)
      exchange_return.update_columns(cash_installments_count: 1)
      entity_transaction.update_columns(price_to_be_returned: -999, exchanges_count: 1)
      entity_transaction.exchanges.update_all(exchanges_count: 1)

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:updated_count]).to eq(1)
      expect(exchange_return.reload.cash_installments.order(:number).pluck(:number, :date, :month, :year, :price)).to eq(
        [
          [ 1, Time.zone.local(2026, 4, 10, 0, 0, 0), 4, 2026, -1_000 ],
          [ 2, Time.zone.local(2026, 5, 10, 0, 0, 0), 5, 2026, -1_000 ]
        ]
      )
      expect(entity_transaction.reload.price).to eq(-2_000)
      expect(entity_transaction.reload.price_to_be_returned).to eq(-2_000)
      expect(entity_transaction.exchanges_count).to eq(2)
      expect(entity_transaction.exchanges.reload.pluck(:exchanges_count).uniq).to eq([ 2 ])
    end

    it "does not overwrite entity_transaction.price when it originally differed from price_to_be_returned" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Runner drift keep price",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))

      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity: receiver_entity, price: -1_500, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000,
                        date: Date.new(2026, 5, 10), month: 5, year: 2026)

      exchange_return = first_exchange.cash_transaction.reload
      exchange_return.cash_installments.delete_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -2_000, starting_price: -2_000,
                                                paid: false, cash_installments_count: 1)
      exchange_return.update_columns(cash_installments_count: 1)
      entity_transaction.update_columns(price_to_be_returned: -999, exchanges_count: 1)
      entity_transaction.exchanges.update_all(exchanges_count: 1)

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:updated_count]).to eq(1)
      expect(entity_transaction.reload.price).to eq(-1_500)
      expect(entity_transaction.price_to_be_returned).to eq(-2_000)
    end
  end
end
