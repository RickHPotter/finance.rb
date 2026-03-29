# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CardBoundExchangeIntegrityAudit do
  describe "#call" do
    it "reports orphaned card-bound exchange families and the expected shared projection" do
      user = create(:user)
      card = create(:card, :random, bank: create(:bank, :random))
      user_card = create(:user_card, :random, user:, card:)
      receiver_entity = create(:entity, user:)

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Audit card-bound orphan",
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

      orphan_projection = first_exchange.cash_transaction
      Exchange.where(id: [ first_exchange.id, second_exchange.id ]).update_all(cash_transaction_id: nil)
      orphan_projection.cash_installments.delete_all
      orphan_projection.delete

      report = described_class.new(ids: [ first_exchange.id, second_exchange.id ]).call
      candidate = report[:candidates].first

      expect(report[:families_count]).to eq(1)
      expect(candidate[:issues]).to include("missing_projection_cash_transaction")
      expect(candidate[:entity_transaction_ids]).to eq([ entity_transaction.id ])
      expect(candidate[:user_card_id]).to eq(user_card.id)
      expect(candidate[:year]).to eq(2026)
      expect(candidate[:month]).to eq(4)
      expect(candidate[:exchanges_count]).to eq(2)
      expect(candidate[:exchanges_sum_price]).to eq(-2_000)
      expect(candidate[:exchange_ids]).to match_array([ first_exchange.id, second_exchange.id ])
    end
  end
end
