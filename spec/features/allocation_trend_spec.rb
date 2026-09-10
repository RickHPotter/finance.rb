# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Allocation trend dashboards", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "loads an exact category report and restores changed filters from the URL" do
    bank = create(:bank, :random)
    account = create(:user_bank_account, user:, bank:)
    category = create(:category, user:, category_name: "TRAVEL REPORT")
    entity = create(:entity, user:, entity_name: "TREND COUNTERPART")
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price: -1_500
    )
    create(:category_transaction, transactable: transaction, category:)
    create(:entity_transaction, transactable: transaction, entity:)
    path = category_path(
      category,
      from_date: "2026-07-01",
      to_date: "2026-07-31",
      granularity: "month",
      paid_state: "all",
      direction: "all"
    )

    visit path
    trend = find("#category_#{category.id}_trend")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", trend)

    expect(trend).to have_css("[data-allocation-trend-target='content']:not(.hidden)")
    expect(trend).to have_text("TREND COUNTERPART")
    expect(trend).to have_css("a[href*='/cash_transactions']")

    find("#category_#{category.id}_trend_direction").select(I18n.t("reports.allocation_trend.options.direction.outcome"))
    expect(page).to have_current_path(category_path(category), ignore_query: true)
    expect(Rack::Utils.parse_query(URI.parse(page.current_url).query)).to include(
      "from_date" => "2026-07-01",
      "to_date" => "2026-07-31",
      "granularity" => "month",
      "paid_state" => "all",
      "direction" => "outcome",
      "sort" => "date_asc"
    )

    updated_path = URI.parse(page.current_url).request_uri
    refresh_browser_at(updated_path)
    expect(page).to have_select("category_#{category.id}_trend_direction", selected: I18n.t("reports.allocation_trend.options.direction.outcome"))
    expect(page).to have_css("#category_#{category.id}_trend [data-allocation-trend-target='content']:not(.hidden)")
  end

  it "loads bank-account families, payment states, stored balances, and exact cash links" do
    bank = create(:bank, :random)
    account = create(:user_bank_account, user:, bank:)
    ordinary = create_cash_transaction(account:, price: 1_000, description: "Ordinary report movement")
    food = create(:category, user:, category_name: "Interactive food")
    ana = create(:entity, user:, entity_name: "Interactive Ana")
    create(:category_transaction, transactable: ordinary, category: food)
    create(:entity_transaction, transactable: ordinary, entity: ana)
    transfer = create_cash_transaction(account:, price: -500, description: "Transfer report movement")
    create(:category_transaction, transactable: transfer, category: user.built_in_category("EXCHANGE"))
    account.update_columns(balance: 12_345)
    ordinary.cash_installments.sole.update_columns(balance: 9_876, order_id: 1)
    path = user_bank_account_path(
      account,
      from_date: "2026-07-01",
      to_date: "2026-07-31",
      granularity: "month",
      paid_state: "all",
      direction: "all"
    )

    visit path
    report = find("#user_bank_account_#{account.id}_movement")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", report)

    expect(report).to have_css("[data-allocation-trend-target='content']:not(.hidden)")
    expect(report).to have_text(I18n.t("reports.bank_account_movement.families.ordinary"))
    expect(report).to have_text(I18n.t("reports.bank_account_movement.families.transfer"))
    expect(report).to have_text(/#{Regexp.escape(I18n.t('reports.bank_account_movement.current_account_balance'))}/i)
    expect(report).to have_text(/#{Regexp.escape(I18n.t('reports.bank_account_movement.first_recorded'))}/i)
    expect(report).to have_text("R$ 123.45")
    expect(report).to have_text("R$ -5.00")
    expect(report).to have_css("[data-allocation-trend-target='paymentStateList'] li", count: 2)
    expect(report).to have_css("a[href*='/cash_transactions']")
    expect(report).to have_select("user_bank_account_#{account.id}_movement_interactive_category_primary", with_options: [ "Interactive food" ])
    expect(report).to have_text("Interactive Ana")
  end

  it "renders card billing metadata and generated identities without duplicate spend" do
    user_card = create(:user_card, :random, user:)
    reference = create(:reference, user_card:, context: user.main_context, month: 7, year: 2026, reference_date: Date.new(2026, 7, 12))
    reference.update_columns(reference_closing_date: Date.new(2026, 7, 5))
    purchase = create_card_report_transaction(
      user_card:,
      description: "Visible card purchase",
      price: -1_000,
      purchase_date: Date.new(2026, 6, 20),
      installment_date: Date.new(2026, 6, 28)
    )
    food = create(:category, user:, category_name: "Interactive card food")
    ana = create(:entity, user:, entity_name: "Interactive card Ana")
    create(:category_transaction, transactable: purchase, category: food)
    create(:entity_transaction, transactable: purchase, entity: ana)
    advance = create_card_report_transaction(
      user_card:,
      description: "Visible card advance",
      price: -500,
      purchase_date: Date.new(2026, 6, 21),
      installment_date: Date.new(2026, 6, 29),
      categories: [ user.built_in_category("CARD ADVANCE") ]
    )
    path = user_card_path(
      user_card,
      from_date: "2026-07-01",
      to_date: "2026-07-31",
      granularity: "month",
      paid_state: "all",
      direction: "all"
    )

    visit path
    report = find("#user_card_#{user_card.id}_movement")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", report)

    expect(report).to have_css("[data-allocation-trend-target='content']:not(.hidden)")
    expect(report).to have_text(I18n.t("reports.user_card_movement.families.advance"))
    expect(report).to have_text("Visible card purchase")
    expect(report).to have_text("Visible card advance")
    expect(report).to have_text("Jun 20, 2026")
    expect(report).to have_text("Jun 28, 2026")
    expect(report).to have_text("Jul 5, 2026")
    expect(report).to have_text("Jul 12, 2026")
    expect(report).to have_text("CashTransaction ##{purchase.card_installments.sole.cash_transaction_id}")
    expect(report).to have_text("CashTransaction ##{advance.advance_cash_transaction_id}")
    expect(report).to have_css("[data-allocation-trend-target='detailList'] li", count: 2)
    expect(report).to have_css("a[href*='/card_transactions']", minimum: 1)
    expect(report).to have_select("user_card_#{user_card.id}_movement_interactive_entity_primary", with_options: [ "Interactive card Ana" ])
    find("#user_card_#{user_card.id}_movement_interactive_entity_primary").select("Interactive card Ana")
    expect(report).to have_text("Interactive card food")
  end

  def create_cash_transaction(account:, price:, description:)
    create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description:,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid: false) ]
    )
  end

  def create_card_report_transaction(user_card:, description:, price:, purchase_date:, installment_date:, categories: [])
    attributes = {
      user_card:,
      description:,
      date: purchase_date,
      month: 7,
      year: 2026,
      price:,
      card_installments: [ build(:card_installment, number: 1, price:, date: installment_date, month: 7, year: 2026, paid: false) ]
    }
    if categories.any? { |category| category.category_name == "CARD ADVANCE" }
      transaction = CardTransaction.new_advanced_payment(user, attributes, context: user.main_context)
      transaction.save!
      return transaction
    end

    create(
      :card_transaction,
      user:,
      context: user.main_context,
      **attributes,
      category_transactions: [],
      entity_transactions: []
    )
  end
end
