# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::LegacyExchangeReturnConsolidationAudit do
  describe "#call" do
    def insert_exchange!(**attrs)
      now = Time.current

      Exchange.insert({
                        entity_transaction_id: attrs[:entity_transaction].id,
                        cash_transaction_id: attrs[:cash_transaction].id,
                        bound_type: "standalone",
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        number: attrs[:number],
                        date: attrs[:date],
                        month: attrs[:month],
                        year: attrs[:year],
                        price: attrs[:price],
                        starting_price: attrs[:price],
                        exchanges_count: 1,
                        created_at: now,
                        updated_at: now
                      })
    end

    it "groups standalone exchange returns that belong to the same payer entity transaction" do
      user = create(:user, :random)
      entity = create(:entity, user:, entity_name: "COUNTERPART")
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      card_transaction = create(:card_transaction, user:, context: user.main_context, user_card: create(:user_card, user:))
      payer_entity_transaction = card_transaction.entity_transactions.first
      payer_entity_transaction.update!(entity:, is_payer: true, price: 2_000, price_to_be_returned: 2_000)

      first_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        description: "Legacy return one",
        cash_transaction_type: "Exchange",
        price: 900,
        date: Date.new(2026, 3, 15),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 15), month: 3, year: 2026, price: 900, paid: false } ]
      )
      first_return.cash_installments.destroy_all
      first_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 15), month: 3, year: 2026, price: 900, paid: false)
      first_return.update_column(:cash_installments_count, 1)
      second_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        description: "Legacy return two",
        cash_transaction_type: "Exchange",
        price: 1_100,
        date: Date.new(2026, 4, 25),
        month: 4,
        year: 2026,
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 4, 25), month: 4, year: 2026, price: 1_100, paid: true } ]
      )
      second_return.cash_installments.destroy_all
      second_return.cash_installments.create!(number: 1, date: Date.new(2026, 4, 25), month: 4, year: 2026, price: 1_100, paid: true)
      second_return.update_column(:cash_installments_count, 1)

      insert_exchange!(entity_transaction: payer_entity_transaction, cash_transaction: first_return, number: 1, price: 900, date: Date.new(2026, 3, 15), month: 3,
                       year: 2026)
      insert_exchange!(entity_transaction: payer_entity_transaction, cash_transaction: second_return, number: 1, price: 1_100, date: Date.new(2026, 4, 25), month: 4,
                       year: 2026)

      report = described_class.new.call
      candidate = report[:candidates].first

      expect(report[:candidates_count]).to eq(1)
      expect(candidate[:survivor_transaction_id]).to eq(first_return.id)
      expect(candidate[:exchange_return_transaction_ids]).to eq([ first_return.id, second_return.id ])
      expect(candidate[:desired_installments].map { |row| row[:number] }).to eq([ 1, 2 ])
    end
  end
end
