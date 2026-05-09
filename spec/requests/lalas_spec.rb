# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lalas", type: :request do
  describe "context scoping" do
    it "renders the dynamic external root for an entity ledger" do
      user = create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-external-root@example.com")
      create(:entity, user:, entity_name: "LALA")

      get external_root_path(user_slug: "rikki", entity_slug: "lala")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(external_cash_transactions_path(user_slug: "rikki", entity_slug: "lala"))
    end

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

    it "supports dynamic external cash routes scoped by user and entity slugs" do
      user = create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-external-cash@example.com")
      bank = create(:bank, :random)
      account = create(:user_bank_account, :random, user:, bank:)
      sograo = create(:entity, user:, entity_name: "SOGRAO")
      lala = create(:entity, user:, entity_name: "LALA")
      exchange_return = user.built_in_category("EXCHANGE RETURN")

      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: account,
        description: "SOGRAO CASH MAIN",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 4,
        year: 2026,
        price: -1000,
        category_transactions_attributes: [ { category_id: exchange_return.id } ],
        entity_transactions_attributes: [ { entity_id: sograo.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 4, year: 2026, price: -1000, paid: false } ]
      )

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

      get month_year_external_cash_transactions_path(user_slug: "rikki", entity_slug: "sograo"), params: { month_year: "202604" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SOGRAO CASH MAIN")
      expect(response.body).not_to include("LALA CASH MAIN")
    end

    it "supports authenticated internal cash routes scoped by current user and entity slug" do
      owner = create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-internal-cash@example.com")
      other_user = create(:user, first_name: "Other", last_name: "Person", email: "other-internal-cash@example.com")
      bank = create(:bank, :random)
      owner_account = create(:user_bank_account, :random, user: owner, bank:)
      other_account = create(:user_bank_account, :random, user: other_user, bank:)
      owner_sograo = create(:entity, user: owner, entity_name: "SOGRAO")
      other_sograo = create(:entity, user: other_user, entity_name: "SOGRAO")
      owner_exchange_return = owner.built_in_category("EXCHANGE RETURN")
      other_exchange_return = other_user.built_in_category("EXCHANGE RETURN")

      create(
        :cash_transaction,
        user: owner,
        context: owner.main_context,
        user_bank_account: owner_account,
        description: "OWNER SOGRAO CASH",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 4,
        year: 2026,
        price: -1000,
        category_transactions_attributes: [ { category_id: owner_exchange_return.id } ],
        entity_transactions_attributes: [ { entity_id: owner_sograo.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 4, year: 2026, price: -1000, paid: false } ]
      )

      create(
        :cash_transaction,
        user: other_user,
        context: other_user.main_context,
        user_bank_account: other_account,
        description: "OTHER SOGRAO CASH",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 4,
        year: 2026,
        price: -1000,
        category_transactions_attributes: [ { category_id: other_exchange_return.id } ],
        entity_transactions_attributes: [ { entity_id: other_sograo.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 4, year: 2026, price: -1000, paid: false } ]
      )

      sign_in owner

      get month_year_internal_cash_transactions_path(entity_slug: "sograo"), params: { month_year: "202604" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OWNER SOGRAO CASH")
      expect(response.body).not_to include("OTHER SOGRAO CASH")
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

    it "supports dynamic external card routes scoped by user and entity slugs" do
      user = create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-external-card@example.com")
      bank = create(:bank, :random)
      card = create(:card, :random, bank:)
      user_card = create(:user_card, :random, user:, card:, due_date_day: 10)
      sograo = create(:entity, user:, entity_name: "SOGRAO")
      lala = create(:entity, user:, entity_name: "LALA")
      exchange = user.built_in_category("EXCHANGE")

      sograo_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "SOGRAO CARD MAIN",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 5,
        year: 2026,
        price: -1000,
        card_installments: [
          build(:card_installment, number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 5, year: 2026, price: -1000)
        ]
      )
      sograo_transaction.category_transactions.destroy_all
      sograo_transaction.entity_transactions.destroy_all
      sograo_transaction.category_transactions.create!(category: exchange)
      sograo_transaction.entity_transactions.create!(entity: sograo, is_payer: false, price: 0, price_to_be_returned: 0)

      lala_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "LALA CARD MAIN",
        date: Time.zone.local(2026, 4, 7, 12),
        month: 5,
        year: 2026,
        price: -1000,
        card_installments: [
          build(:card_installment, number: 1, date: Time.zone.local(2026, 4, 7, 12), month: 5, year: 2026, price: -1000)
        ]
      )
      lala_transaction.category_transactions.destroy_all
      lala_transaction.entity_transactions.destroy_all
      lala_transaction.category_transactions.create!(category: exchange)
      lala_transaction.entity_transactions.create!(entity: lala, is_payer: false, price: 0, price_to_be_returned: 0)

      get month_year_external_card_transactions_path(user_slug: "rikki", entity_slug: "sograo"), params: {
        month_year: "202605",
        card_transaction: { user_card_id: user_card.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SOGRAO CARD MAIN")
      expect(response.body).not_to include("LALA CARD MAIN")
    end

    it "renders the authenticated internal root for the current user's entity ledger" do
      user = create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-internal-root@example.com")
      create(:entity, user:, entity_name: "LALA")
      sign_in user

      get internal_root_path(entity_slug: "lala")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(internal_cash_transactions_path(entity_slug: "lala"))
    end
  end
end
