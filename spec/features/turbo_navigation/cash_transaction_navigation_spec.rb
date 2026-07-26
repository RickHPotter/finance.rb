# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash transaction Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:transaction_date) { 1.month.from_now.to_date }

  before do
    bank_account
    category
    entity
    sign_in user
  end

  it "replaces a successfully submitted new form with the canonical cash index" do
    visit cash_transactions_path
    find("#new_cash_transaction").click

    expect_browser_path(new_cash_transaction_path)

    new_path = seeded_new_path(description: "Browser canonical create")
    page.execute_script("Turbo.visit(arguments[0], { action: 'replace' })", new_path)

    expect_browser_path(new_path)
    expect_workflow_finishing_submitter("#transaction_form button[type='submit']")
    expect_local_reactive_submitter("#transaction_form [data-reactive-form-target='updateButton']")

    find("#transaction_form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(cash_transactions_path)
    expect(page).to have_css("turbo-frame#cash_transactions")
    expect(user.main_context.cash_transactions.where(description: "Browser canonical create")).to exist

    browser_back_to(cash_transactions_path)
    browser_forward_to(cash_transactions_path)
    refresh_browser_at(cash_transactions_path)
  end

  it "keeps the canonical new URL and entered form when validation fails" do
    new_path = seeded_new_path(description: "Browser invalid create")
    visit new_path
    fill_in "cash_transaction_description", with: ""

    find("#transaction_form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(new_path)
    expect(page).to have_css("turbo-frame#new_cash_transaction")
    expect(page).to have_field("cash_transaction_description", with: "")
    expect(page).to have_css("#notification-content")
  end

  it "replaces a successfully submitted edit form with its canonical return index" do
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: bank_account,
      categories: [ category ],
      entities: [ entity ],
      date: transaction_date,
      month: transaction_date.month,
      year: transaction_date.year
    )
    visit cash_transactions_path
    edit_path = edit_cash_transaction_path(transaction, return_to: cash_transactions_path)
    page.execute_script("Turbo.visit(arguments[0])", edit_path)
    fill_in "cash_transaction_description", with: "Browser canonical update"

    find("#transaction_form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(cash_transactions_path)
    expect(transaction.reload.description).to eq("Browser canonical update")
    browser_back_to(cash_transactions_path)
    browser_forward_to(cash_transactions_path)
  end

  def seeded_new_path(description:)
    new_cash_transaction_path(
      return_to: cash_transactions_path,
      cash_transaction: {
        description:,
        price: 12_345,
        date: transaction_date.iso8601,
        month: transaction_date.month,
        year: transaction_date.year,
        user_bank_account_id: bank_account.id,
        category_id: category.id,
        entity_id: entity.id,
        cash_installments_attributes: {
          "0" => {
            number: 1,
            date: transaction_date.iso8601,
            month: transaction_date.month,
            year: transaction_date.year,
            price: 12_345,
            paid: false
          }
        }
      }
    )
  end
end
