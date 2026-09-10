# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Monthly Analysis source navigation", type: :feature do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:, entity_name: "CONNECTED ENTITY") }

  before { sign_in user }

  it "renders exact transfer, Piggy Bank, generated-return, and valuation links" do
    transfer = create_cash_source(description: "Connected transfer", price: -1_000, category_name: "EXCHANGE")
    piggy_source = create_piggy_bank_source
    piggy_return = piggy_source.piggy_bank.return_cash_transaction
    valuation = create(
      :investment,
      user:,
      context:,
      user_bank_account: account,
      investment_type: create(:investment_type, :random),
      description: "Connected valuation",
      price: 250,
      date: Date.new(2026, 7, 15),
      month: 7,
      year: 2026,
      piggy_bank_return_cash_transaction: piggy_return
    )
    return_to = balances_path(tab: "monthly_analysis", month: "2026-07")

    visit return_to
    report = find("[data-controller='balances-monthly-analysis']")

    expect(report).to have_css("[data-balances-monthly-analysis-target='content']:not(.hidden)")
    expect(report).to have_text(I18n.t("balances.monthly_analysis.source"))
    expect(report).to have_text(I18n.t("balances.monthly_analysis.generated_return"))
    expect(report).to have_text(I18n.t("balances.monthly_analysis.valuation"))
    expect(report).to have_css("a[href='#{cash_transaction_path(transfer, return_to:)}']")
    expect(report).to have_css("a[href='#{cash_transaction_path(piggy_source, return_to:)}']")
    expect(report).to have_css("a[href='#{cash_transaction_path(piggy_return, return_to:)}']")
    expect(report).to have_css("a[href='#{investment_path(valuation, return_to:)}']")

    report.find("a[href='#{cash_transaction_path(transfer, return_to:)}']").click
    expect(page).to have_current_path(cash_transaction_path(transfer, return_to:))
  end

  private

  def create_cash_source(description:, price:, category_name:)
    transaction = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description:,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid: true) ],
      category_transactions: [],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ]
    )
    create(:category_transaction, transactable: transaction, category: user.built_in_category(category_name))
    transaction
  end

  def create_piggy_bank_source
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description: "Connected reserve",
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid: true) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: Date.new(2026, 7, 31))
    )
  end
end
