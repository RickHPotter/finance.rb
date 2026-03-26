# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::LegacyExchangeReturnRunner do
  describe "#call" do
    it "syncs canonical standalone exchanges from legacy exchange return installments without changing the installments" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_entity_for_receiver = create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_entity_for_sender = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

      exchange_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Legacy exchange return",
        cash_transaction_type: "Exchange",
        price: 2_000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: sender_entity_for_receiver.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 2_000, paid: false }
        ]
      )
      exchange_return.cash_installments.destroy_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 2_000, paid: false)
      exchange_return.update_column(:cash_installments_count, 1)

      receiver_shared_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: exchange_return,
        description: "Borrow return",
        price: -2_000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_entity_for_sender.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1_000, paid: true },
          { number: 2, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -1_000, paid: false }
        ]
      )
      receiver_shared_return.cash_installments.destroy_all
      receiver_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1_000, paid: true)
      receiver_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -1_000, paid: false)
      receiver_shared_return.update_column(:cash_installments_count, 2)

      card_transaction = create(:card_transaction, user: sender, context: sender.main_context, user_card: create(:user_card, user: sender))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity: sender_entity_for_receiver, is_payer: true, price: 2_000, price_to_be_returned: 2_000)
      create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 1, price: 1_000, date: Date.new(2026, 3, 10),
                        month: 3, year: 2026)
      create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 2, price: 1_000, date: Date.new(2026, 4, 10),
                        month: 4, year: 2026)
      exchange_return.cash_installments.delete_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 2_000, paid: true)
      exchange_return.update_column(:cash_installments_count, 1)

      original_installment_snapshot = exchange_return.cash_installments.order(:number).pluck(:number, :date, :month, :year, :price, :paid)

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:updated_count]).to eq(1)
      expect(result[:updates].first[:desired_exchange_rows]).to eq(
        [
          { number: 1, date: "2026-03-10", month: 3, year: 2026, price: 2_000 }
        ]
      )
      expect(exchange_return.reload.cash_installments.order(:number).pluck(:number, :date, :month, :year, :price, :paid)).to eq(original_installment_snapshot)
      expect(exchange_return.exchanges.monetary.order(:number).pluck(:number, :price, :month, :year)).to eq(
        [
          [ 1, 2_000, 3, 2026 ]
        ]
      )
    end

    it "ignores card-bound exchange returns" do
      user = create(:user, :random)
      entity = create(:entity, user:)
      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        description: "Card bound return",
        cash_transaction_type: "Exchange",
        price: 1_000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 900, paid: false }
        ]
      )
      exchange_return.cash_installments.destroy_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: 900, paid: false)
      exchange_return.update_column(:cash_installments_count, 1)

      card_transaction = create(:card_transaction, user:, context: user.main_context, user_card: create(:user_card, user:))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity:, is_payer: true, price: 1_000, price_to_be_returned: 1_000)
      create(:exchange, entity_transaction:, cash_transaction: exchange_return, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: 1_000,
                        date: Date.new(2026, 3, 10), month: 3, year: 2026)

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:updated_count]).to eq(0)
      expect(result[:skipped_count]).to eq(0)
      expect(exchange_return.reload.exchanges.monetary.order(:number).pluck(:number, :price)).to eq([ [ 1, 1_000 ] ])
    end
  end
end
