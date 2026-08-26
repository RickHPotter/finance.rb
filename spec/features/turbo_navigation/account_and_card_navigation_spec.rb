# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bank-account and user-card Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }

  before { sign_in user }

  it "returns a saved inactive account edit to its filtered account index" do
    account = create(:user_bank_account, :random, user:, bank:, active: false)
    return_to = Navigation::UserBankAccounts.new(
      raw: user_bank_accounts_path(search_term: account.user_bank_account_name, user_bank_account: { status: [ "inactive" ] }),
      fallback: user_bank_accounts_path,
      current_user: user
    ).destination

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_user_bank_account_path(account, return_to:),
      record: account,
      field: { id: "user_bank_account_user_bank_account_name", value: "CANONICAL ACCOUNT UPDATE", attribute: :user_bank_account_name }
    )
  end

  it "returns a saved inactive card edit to its filtered card index" do
    user_card = create(:user_card, :random, user:, card:, active: false)
    return_to = Navigation::UserCards.new(
      raw: user_cards_path(search_term: user_card.user_card_name, user_card: { status: [ "inactive" ] }),
      fallback: user_cards_path,
      current_user: user
    ).destination

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_user_card_path(user_card, return_to:),
      record: user_card,
      field: { id: "user_card_user_card_name", value: "CANONICAL CARD UPDATE", attribute: :user_card_name }
    )
  end

  def exercise_edit_navigation(index_path:, edit_path:, record:, field:)
    visit index_path
    page.execute_script("Turbo.visit(arguments[0])", edit_path)
    replace_field field[:id], with: field[:value]

    expect_workflow_finishing_submitter("form button[type='submit']")
    find("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(index_path)
    expect(record.reload.public_send(field[:attribute])).to eq(field[:value])
    browser_back_to(index_path)
    browser_forward_to(index_path)
    refresh_browser_at(index_path)
  end
end
