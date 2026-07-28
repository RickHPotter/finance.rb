# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Turbo navigation final regressions", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "preserves canonical state through a representative cross-resource journey" do
    cash_path = cash_transactions_path(search_term: "CROSS RESOURCE")

    visit cash_path
    expect_browser_path(cash_path)

    find("#tabs a[href='#{user_bank_accounts_path}']", visible: :visible, match: :first).click
    expect_browser_path(user_bank_accounts_path)

    find("#tabs a[href='#{categories_path}']", visible: :visible, match: :first).click
    expect_browser_path(categories_path)

    page.execute_script("Turbo.visit(arguments[0])", budgets_path)
    expect_browser_path(budgets_path)

    browser_back_to(categories_path)
    browser_back_to(user_bank_accounts_path)
    browser_back_to(cash_path)
    browser_forward_to(user_bank_accounts_path)
    browser_forward_to(categories_path)
    browser_forward_to(budgets_path)
    refresh_browser_at(budgets_path)
  end

  it "replaces a destroyed member screen so browser restoration cannot revive it" do
    category = create(:category, :random, user:)

    visit categories_path
    page.execute_script("Turbo.visit(arguments[0])", category_path(category))
    expect_browser_path(category_path(category))

    find("#delete_category_#{category.id}").click
    within("#linkWithConfirmDialog_category_dashboard_destroy_#{category.id}", visible: :all) do
      find("button[data-action='confirm#proceed']", visible: :all).click
    end

    expect_browser_path(categories_path)
    expect(Category.exists?(category.id)).to be(false)

    browser_back_to(categories_path)
    expect(page).to have_no_css("#delete_category_#{category.id}", visible: :all)
    refresh_browser_at(categories_path)
  end
end
