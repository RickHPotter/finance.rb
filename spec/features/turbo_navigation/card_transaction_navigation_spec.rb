# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card transaction Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:transaction_date) { 1.month.from_now.to_date }
  let(:card_transaction) do
    create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card:,
      categories: [ category ],
      entities: [ entity ],
      description: "Browser card navigation",
      date: transaction_date,
      month: transaction_date.month,
      year: transaction_date.year
    )
  end

  before do
    card_transaction
    sign_in user
  end

  it "replaces a successfully submitted edit form with the selected invoice index" do
    installment = card_transaction.card_installments.first
    active_month_year = Date.new(installment.year, installment.month, 1).strftime("%Y%m").to_i
    return_to = card_transactions_path(
      user_card_id: user_card.id,
      default_year: transaction_date.year,
      active_month_years: [ active_month_year ].to_json
    )
    edit_path = edit_card_transaction_path(card_transaction, return_to:)
    expected_path = Navigation::CardTransactions.new(
      raw: return_to,
      fallback: card_transactions_path,
      current_user: user,
      current_context: user.main_context
    ).destination

    visit expected_path
    page.execute_script("Turbo.visit(arguments[0])", edit_path)
    fill_in "card_transaction_description", with: "Browser canonical card update"

    expect_workflow_finishing_submitter("#transaction_form button[type='submit']")
    expect_local_reactive_submitter("#transaction_form [data-reactive-form-target='updateButton']")

    find("#transaction_form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(expected_path)
    expect(card_transaction.reload.description).to eq("Browser canonical card update")
    browser_back_to(expected_path)
    browser_forward_to(expected_path)
    refresh_browser_at(expected_path)
  end

  it "keeps the canonical edit URL and entered form when validation fails" do
    edit_path = edit_card_transaction_path(card_transaction, return_to: card_transactions_path(user_card_id: user_card.id))
    visit edit_path
    fill_in "card_transaction_description", with: ""

    find("#transaction_form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(edit_path)
    expect(page).to have_css("turbo-frame#card_transaction_#{card_transaction.id}")
    expect(page).to have_field("card_transaction_description", with: "")
    expect(page).to have_css("#notification-content")
  end

  it "keeps pay-in-advance on the selected invoice URL" do
    installment = card_transaction.card_installments.first
    cycle_date = Date.new(installment.year, installment.month, 1)
    reference = user_card.references.find_or_initialize_by(
      context: user.main_context,
      month: installment.month,
      year: installment.year
    )
    reference.assign_attributes(
      reference_date: cycle_date.end_of_month,
      reference_closing_date: cycle_date.change(day: 10),
      skip_reference_closing_date_calculation: true
    )
    reference.save!
    selected_invoice_path = card_transactions_path(
      user_card_id: user_card.id,
      default_year: installment.year,
      active_month_years: [ cycle_date.strftime("%Y%m").to_i ].to_json
    )
    expected_path = Navigation::CardTransactions.new(
      raw: selected_invoice_path,
      fallback: card_transactions_path,
      current_user: user,
      current_context: user.main_context
    ).destination

    visit expected_path
    expect(page).to have_css("form[action='#{pay_in_advance_card_transactions_path}']", visible: :all)

    page.execute_script("document.querySelector(arguments[0]).requestSubmit()", "form[action='#{pay_in_advance_card_transactions_path}']")

    expect(page).to have_css("#notification-content", text: CardTransaction.model_name.human)
    expect_browser_path(expected_path)
  end
end
