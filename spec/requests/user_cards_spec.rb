# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserCards", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get user_cards_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #new ]" do
    it "renders the ruby ui combobox" do
      get new_user_card_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("ruby-ui--combobox")
      expect(response.body).not_to include("hw-combobox")
    end
  end

  describe "[ #create ]" do
    it "creates a user card" do
      expect do
        post user_cards_path, params: {
          user_card: {
            user_card_name: "Gaara",
            due_date_day: 10,
            days_until_due_date: 7,
            min_spend: 10_000,
            credit_limit: 200_000,
            active: true,
            card_id: card.id,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(UserCard, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      user_card = create(:user_card, user:, card:)

      patch user_card_path(user_card), params: {
        user_card: {
          user_card_name: "Sasuke",
          due_date_day: user_card.due_date_day,
          days_until_due_date: user_card.days_until_due_date,
          min_spend: user_card.min_spend,
          credit_limit: user_card.credit_limit,
          active: user_card.active,
          card_id: card.id,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(user_card.reload.user_card_name).to eq("Sasuke")
    end

    it "updates unpaid invoices and exchange returns inside each context without crossing records" do
      user_card = create(:user_card, user:, card:, due_date_day: 12, days_until_due_date: 5)
      card_payment_category = user.built_in_category("CARD PAYMENT")

      create(:reference, context: user.main_context, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12),
                         reference_closing_date: Date.new(2026, 3, 7))

      main_invoice = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        description: "Main Invoice",
        cash_transaction_type: "CardInstallment",
        date: Date.new(2026, 3, 12),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_invoice.categories = [ card_payment_category ]
      main_invoice.save!

      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Main Purchase",
        date: Date.new(2026, 2, 10),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_card_transaction.card_installments.first.update!(cash_transaction: main_invoice, month: 3, year: 2026)

      main_entity_transaction = main_card_transaction.entity_transactions.first
      main_entity_transaction.update!(price: -1000, price_to_be_returned: -1000, is_payer: true, exchanges_count: 1)
      main_exchange = create(
        :exchange,
        entity_transaction: main_entity_transaction,
        bound_type: :card_bound,
        exchange_type: :monetary,
        number: 1,
        month: 3,
        year: 2026,
        date: Date.new(2026, 3, 12),
        price: -1000
      )
      main_exchange_return = main_exchange.cash_transaction
      main_exchange_return.cash_installments.first.update!(paid: false)
      main_exchange_return.update_column(:paid, false)

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Card schedule isolation"
      ).call

      derived_invoice = user_card.unpaid_invoices(context: derived_context).find_by!(month: 3, year: 2026)
      derived_exchange_return = derived_context.cash_transactions.find_by!(description: main_exchange_return.description)
      derived_exchange = derived_exchange_return.exchanges.first
      derived_exchange_return.cash_installments.first.update!(paid: false)
      derived_exchange_return.update_column(:paid, false)

      patch user_card_path(user_card), params: {
        user_card: {
          user_card_name: user_card.user_card_name,
          min_spend: user_card.min_spend,
          credit_limit: user_card.credit_limit,
          active: user_card.active,
          card_id: card.id,
          user_id: user.id,
          current_closing_date: Date.new(2026, 3, 10),
          current_due_date: Date.new(2026, 3, 20)
        }
      }, headers: turbo_stream_headers

      expect(main_invoice.reload.context).to eq(user.main_context)
      expect(derived_invoice.reload.context).to eq(derived_context)
      expect(main_invoice.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(derived_invoice.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(main_exchange_return.reload.context).to eq(user.main_context)
      expect(derived_exchange_return.reload.context).to eq(derived_context)
      expect(main_exchange_return.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(derived_exchange_return.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(main_exchange.reload.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(derived_exchange.reload.date.to_date).to eq(Date.new(2026, 3, 20))
    end
  end

  describe "[ #destroy ]" do
    it "destroys a card without transactions" do
      user_card = create(:user_card, user:, card:)

      expect do
        delete user_card_path(user_card), headers: turbo_stream_headers
      end.to change(UserCard, :count).by(-1)
    end
  end

  describe "[ #reference_date ]" do
    it "returns the reference date as json" do
      user_card = create(:user_card, user:, card:)

      get reference_date_user_card_path(user_card), params: { year: 2026, month: 3 }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include("reference_date")
    end

    it "uses the current context reference date instead of leaking back to main" do
      user_card = create(:user_card, user:, card:, due_date_day: 12, days_until_due_date: 5)
      derived_context = create(:context, user:, name: "Reference Date Isolation", source_context: user.main_context)

      create(:reference, user_card:, context: user.main_context, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12),
                         reference_closing_date: Date.new(2026, 3, 7))
      create(:reference, user_card:, context: derived_context, month: 3, year: 2026, reference_date: Date.new(2026, 3, 20),
                         reference_closing_date: Date.new(2026, 3, 15))

      patch switch_context_path(derived_context)

      get reference_date_user_card_path(user_card), params: { year: 2026, month: 3 }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include("reference_date" => "2026-03-20")
    end
  end
end
