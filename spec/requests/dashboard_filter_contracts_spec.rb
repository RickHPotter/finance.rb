# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard collection filter contracts", type: :request do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:subscription) { create(:subscription, user:, context:) }

  before { sign_in user }

  it "filters cash collections by exact transaction ids and persists the scope in the search form" do
    selected = create_cash_transaction("EXACT CASH DASHBOARD", subscription:)
    excluded = create_cash_transaction("EXCLUDED CASH DASHBOARD")

    get cash_transactions_path(
      active_month_years: [ 202_608 ].to_json,
      cash_transaction: { id: [ selected.id ] }
    )

    document = Nokogiri::HTML.parse(response.body)
    hidden_scope = document.at_css(%(input[type="hidden"][name="cash_transaction[id][]"][value="#{selected.id}"]))

    expect(response).to have_http_status(:success)
    expect(hidden_scope).to be_present

    get month_year_cash_transactions_path(
      month_year: "202608",
      cash_transaction: { id: [ selected.id ] }
    )

    expect(response.body).to include(selected.description)
    expect(response.body).not_to include(excluded.description)
  end

  it "filters cash collections by live subscription membership" do
    selected = create_cash_transaction("SUBSCRIBED CASH DASHBOARD", subscription:)
    excluded = create_cash_transaction("UNSUBSCRIBED CASH DASHBOARD")

    get month_year_cash_transactions_path(
      month_year: "202608",
      cash_transaction: { subscription_id: [ subscription.id ] }
    )

    expect(response.body).to include(selected.description)
    expect(response.body).not_to include(excluded.description)
  end

  it "filters card collections by exact transaction ids and persists the scope in the search form" do
    selected = create_card_transaction("EXACT CARD DASHBOARD", subscription:)
    excluded = create_card_transaction("EXCLUDED CARD DASHBOARD")

    get card_transactions_path(
      active_month_years: [ 202_608 ].to_json,
      card_transaction: { id: [ selected.id ] }
    )

    document = Nokogiri::HTML.parse(response.body)
    hidden_scope = document.at_css(%(input[type="hidden"][name="card_transaction[id][]"][value="#{selected.id}"]))

    expect(response).to have_http_status(:success)
    expect(hidden_scope).to be_present

    get month_year_card_transactions_path(
      month_year: "202608",
      card_transaction: { id: [ selected.id ] }
    )

    expect(response.body).to include(selected.description)
    expect(response.body).not_to include(excluded.description)
  end

  it "filters card collections by live subscription membership" do
    selected = create_card_transaction("SUBSCRIBED CARD DASHBOARD", subscription:)
    excluded = create_card_transaction("UNSUBSCRIBED CARD DASHBOARD")

    get month_year_card_transactions_path(
      month_year: "202608",
      card_transaction: { subscription_id: [ subscription.id ] }
    )

    expect(response.body).to include(selected.description)
    expect(response.body).not_to include(excluded.description)
  end

  it "rejects foreign dashboard identifiers from approved return paths" do
    foreign_user = create(:user, :random)
    foreign_subscription = create(:subscription, user: foreign_user, context: foreign_user.main_context)
    foreign_cash = create(:cash_transaction, :random, user: foreign_user, context: foreign_user.main_context)
    foreign_card = create(:card_transaction, :random, user: foreign_user, context: foreign_user.main_context)

    cash_state = Navigation::CashTransactions.new(
      raw: cash_transactions_path(cash_transaction: { id: [ foreign_cash.id ], subscription_id: [ foreign_subscription.id ] }),
      fallback: cash_transactions_path,
      current_user: user,
      current_context: context
    )
    card_state = Navigation::CardTransactions.new(
      raw: card_transactions_path(card_transaction: { id: [ foreign_card.id ], subscription_id: [ foreign_subscription.id ] }),
      fallback: card_transactions_path,
      current_user: user,
      current_context: context
    )

    expect(cash_state.destination).to eq(cash_transactions_path)
    expect(card_state.destination).to eq(card_transactions_path)
  end

  private

  def create_cash_transaction(description, subscription: nil)
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: bank_account,
      subscription:,
      description:,
      date: Time.zone.local(2026, 8, 10),
      month: 8,
      year: 2026,
      cash_installments: [ build(:cash_installment, number: 1, date: Time.zone.local(2026, 8, 10), month: 8, year: 2026, price: -1_000) ]
    )
  end

  def create_card_transaction(description, subscription: nil)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      subscription:,
      description:,
      date: Time.zone.local(2026, 8, 10),
      month: 8,
      year: 2026,
      card_installments: [ build(:card_installment, number: 1, date: Time.zone.local(2026, 8, 10), month: 8, year: 2026, price: -1_000) ]
    )
  end
end
