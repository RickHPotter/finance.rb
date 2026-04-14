# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lalas", type: :request do
  describe "context scoping" do
    it "shows only main-context cash transactions in the month view" do
      user = create(:user, :random)
      bank = create(:bank, :random)
      account = create(:user_bank_account, :random, user:, bank:)
      derived_context = create(:context, user:, source_context: user.main_context, name: "Derived")
      lala = create(:entity, user:, entity_name: "LALA")
      exchange_return = user.built_in_category("EXCHANGE RETURN")

      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: account,
        description: "LALA CASH MAIN",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 4,
        year: 2026,
        price: -1000,
        category_transactions_attributes: [ { category_id: exchange_return.id } ],
        entity_transactions_attributes: [ { entity_id: lala.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 4, year: 2026, price: -1000, paid: false } ]
      )

      create(
        :cash_transaction,
        user:,
        context: derived_context,
        user_bank_account: account,
        description: "LALA CASH DERIVED",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 4,
        year: 2026,
        price: -1000,
        category_transactions_attributes: [ { category_id: exchange_return.id } ],
        entity_transactions_attributes: [ { entity_id: lala.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 4, year: 2026, price: -1000, paid: false } ]
      )

      get month_year_lalas_cash_transactions_path, params: { month_year: "202604" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LALA CASH MAIN")
      expect(response.body).not_to include("LALA CASH DERIVED")
    end

    it "shows only main-context card transactions in the month view" do
      user = create(:user, :random)
      bank = create(:bank, :random)
      card = create(:card, :random, bank:)
      user_card = create(:user_card, :random, user:, card:, due_date_day: 10)
      derived_context = create(:context, user:, source_context: user.main_context, name: "Derived")
      lala = create(:entity, user:, entity_name: "LALA")
      exchange = user.built_in_category("EXCHANGE")

      main_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "LALA CARD MAIN",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 5,
        year: 2026,
        price: -1000
      )
      main_transaction.category_transactions.destroy_all
      main_transaction.entity_transactions.destroy_all
      main_transaction.category_transactions.create!(category: exchange)
      main_transaction.entity_transactions.create!(entity: lala, is_payer: false, price: 0, price_to_be_returned: 0)

      derived_transaction = create(
        :card_transaction,
        user:,
        context: derived_context,
        user_card:,
        description: "LALA CARD DERIVED",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 5,
        year: 2026,
        price: -1000
      )
      derived_transaction.category_transactions.destroy_all
      derived_transaction.entity_transactions.destroy_all
      derived_transaction.category_transactions.create!(category: exchange)
      derived_transaction.entity_transactions.create!(entity: lala, is_payer: false, price: 0, price_to_be_returned: 0)

      get month_year_lalas_card_transactions_path, params: {
        month_year: "202605",
        card_transaction: { user_card_id: user_card.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LALA CARD MAIN")
      expect(response.body).not_to include("LALA CARD DERIVED")
    end
  end
end
