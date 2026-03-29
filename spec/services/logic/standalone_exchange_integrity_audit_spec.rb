# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::StandaloneExchangeIntegrityAudit do
  describe "#call" do
    it "reports standalone exchange returns whose installments count and price_to_be_returned drifted from exchanges" do
      user = create(:user)
      create(:user_bank_account, user:, bank: create(:bank, :random))
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Audit drift",
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

      report = described_class.new(ids: [ exchange_return.id ]).call
      candidate = report[:candidates].first

      expect(report[:candidates_count]).to eq(1)
      expect(candidate[:exchange_return_transaction_id]).to eq(exchange_return.id)
      expect(candidate[:issues]).to include(
        "cash_installments_count_mismatch",
        "entity_transaction_price_to_be_returned_mismatch",
        "entity_transaction_exchanges_count_mismatch",
        "exchange_row_exchanges_count_mismatch"
      )
      expect(candidate.dig(:desired, :cash_installments_count)).to eq(2)
      expect(candidate.dig(:desired, :entity_transaction_price)).to eq(-2_000)
      expect(candidate.dig(:desired, :entity_transaction_price_to_be_returned)).to eq(-2_000)
    end
  end
end
