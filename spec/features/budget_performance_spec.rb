# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budget performance dashboard", type: :feature do
  let(:user) { create(:user, :random) }
  let(:category) { create(:category, :random, user:, category_name: "HOUSEHOLD") }

  before { sign_in user }

  it "lazy-loads reconciled metrics, rules, and exact cash/card source links" do
    account = create(:user_bank_account, :random, user:)
    user_card = create(:user_card, :random, user:)
    create_cash_source(account:)
    create_card_source(user_card:)
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 9,
      year: 2026,
      value: -10_000,
      budget_categories: [ build(:budget_category, category:) ]
    )

    visit budget_path(budget)
    report = find("#budget_#{budget.id}_performance")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", report)

    expect(report).to have_css("[data-budget-performance-target='content']:not(.hidden)")
    expect(report).to have_text("R$ -100.00")
    expect(report).to have_text("R$ -40.00")
    expect(report).to have_text("R$ -60.00")
    expect(report).to have_text("40%")
    expect(report).to have_text(I18n.t("reports.budget_performance.available"))
    expect(report).to have_text(I18n.t("reports.budget_performance.inclusive_false"))
    expect(report).to have_text(I18n.t("reports.budget_performance.first_installment_only_false"))
    expect(report).to have_css("a[href*='/cash_transactions']", count: 1)
    expect(report).to have_css("a[href*='/card_transactions']", count: 1)
  end

  private

  def create_cash_source(account:)
    create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "Budget cash source",
      date: Date.new(2026, 9, 8),
      month: 9,
      year: 2026,
      price: -2_500,
      cash_installments: [ build(:cash_installment, number: 1, date: Date.new(2026, 9, 8), month: 9, year: 2026, price: -2_500, paid: true) ],
      category_transactions: [ CategoryTransaction.new(category:) ]
    )
  end

  def create_card_source(user_card:)
    create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card:,
      description: "Budget card source",
      date: Date.new(2026, 8, 20),
      month: 9,
      year: 2026,
      price: -1_500,
      card_installments: [ build(:card_installment, number: 1, date: Date.new(2026, 8, 20), month: 9, year: 2026, price: -1_500, paid: false) ],
      category_transactions: [ CategoryTransaction.new(category:) ]
    )
  end
end
