# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Turbo navigation browser harness", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    sign_in user
  end

  it "observes canonical URL, Back, Forward, and refresh behavior" do
    visit cash_transactions_path

    expect_browser_path(cash_transactions_path)
    expect(page).to have_css("turbo-frame#center_container")

    find("#tabs a[href='#{user_bank_accounts_path}']", visible: :visible, match: :first).click

    expect_browser_path(user_bank_accounts_path)
    expect(page).to have_css("turbo-frame#center_container")

    browser_back_to(cash_transactions_path)
    browser_forward_to(user_bank_accounts_path)
    refresh_browser_at(user_bank_accounts_path)
  end

  it "replaces an intermediate Turbo history entry" do
    visit cash_transactions_path
    find("#tabs a[href='#{user_bank_accounts_path}']", visible: :visible, match: :first).click
    expect_browser_path(user_bank_accounts_path)

    page.execute_script("Turbo.visit(arguments[0], { action: 'replace' })", budgets_path)

    expect_browser_path(budgets_path)
    expect(page).to have_css("turbo-frame#center_container")
    browser_back_to(cash_transactions_path)
    browser_forward_to(budgets_path)
    refresh_browser_at(budgets_path)
  end
end
