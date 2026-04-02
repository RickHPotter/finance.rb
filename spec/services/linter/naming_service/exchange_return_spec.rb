# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linter::NamingService::ExchangeReturn, type: :service do
  describe "#call" do
    it "normalizes standalone exchange-return descriptions to the source description without installment suffixes" do
      user = create(:user, :random)
      receiver = create(:user, :random)
      create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: create(:bank, :random)))

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "FINANCIAMENTO LOTE",
        date: Date.new(2026, 2, 7),
        month: 3,
        year: 2026,
        price: -12_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(
        entity_id: user.entities.that_are_users.find_by!(entity_user: receiver).id,
        price: -12_000,
        price_to_be_returned: -12_000,
        is_payer: true,
        exchanges_count: 6
      )
      first_exchange = create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -2_000,
        date: Date.new(2026, 3, 2),
        month: 3,
        year: 2026
      )
      exchange_return = first_exchange.cash_transaction.reload
      exchange_return.update_columns(description: "FINANCIAMENTO LOTE 1/6")

      results = described_class.new(cash_transactions: [ exchange_return ], dry_run: true).call

      expect(results.first.dig(:changes, :description)).to eq("FINANCIAMENTO LOTE")
    end
  end
end
