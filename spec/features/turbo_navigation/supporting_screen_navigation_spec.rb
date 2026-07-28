# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Supporting screen Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "restores the selected balance tab and month after a direct visit and refresh" do
    path = balances_path(tab: "monthly_analysis", month: "2026-05")

    visit path

    expect_browser_path(path)
    expect(page).to have_css("[data-lazy-tabs-name='monthly_analysis'][aria-selected='true']")
    expect(page).to have_field("balances_monthly_analysis_month", with: "2026-05")

    month_input = find("#balances_monthly_analysis_month")
    page.execute_script(<<~JAVASCRIPT, month_input)
      arguments[0].value = "2026-06"
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT

    updated_path = balances_path(tab: "monthly_analysis", month: "2026-06")
    expect_browser_path(updated_path)
    refresh_browser_at(updated_path)
    expect(page).to have_css("[data-lazy-tabs-name='monthly_analysis'][aria-selected='true']")
    expect(page).to have_field("balances_monthly_analysis_month", with: "2026-06")
  end

  it "switches context while preserving a canonical supporting-screen destination" do
    context = create(:context, user:, source_context: user.main_context, name: "Planning context")
    balances_state = balances_path(tab: "monthly_analysis", month: "2026-05")

    visit contexts_path
    page.execute_script("Turbo.visit(arguments[0])", balances_state)
    expect_browser_path(balances_state)

    switch_form = find("form[action='#{switch_context_path(context)}']", match: :first)
    expect(switch_form).to have_field("return_to", with: balances_state, type: :hidden)
    switch_form.find("button", match: :first).click

    expect_browser_path(balances_state)
    expect(page).to have_text("Planning context")
    browser_back_to(contexts_path)
    browser_forward_to(balances_state)
    refresh_browser_at(balances_state)
  end

  it "keeps direct reference edits refreshable and replaces the form URL after save" do
    bank = create(:bank, :random)
    card = create(:card, :random, bank:)
    user_card = create(:user_card, :random, user:, card:)
    reference = create(
      :reference,
      context: user.main_context,
      user_card:,
      month: 5,
      year: 2026,
      reference_date: Date.new(2026, 5, 10),
      reference_closing_date: Date.new(2026, 5, 3)
    )
    return_to = Navigation::UserCards.new(
      raw: user_cards_path(search_term: user_card.user_card_name, user_card: { status: [ "active" ] }),
      fallback: user_cards_path,
      current_user: user
    ).destination
    edit_path = edit_user_card_reference_path(user_card, reference, return_to:)

    visit edit_path
    refresh_browser_at(edit_path)
    page.execute_script(<<~JAVASCRIPT)
      document.querySelector("#reference_reference_closing_date").value = "2026-05-04"
      document.querySelector("#reference_reference_date").value = "2026-05-11"
    JAVASCRIPT

    expect_workflow_finishing_submitter("form input[type='submit']")
    find("form input[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']").click

    destination = edit_user_card_path(user_card, return_to:)
    expect_browser_path(destination)
    expect(reference.reload.reference_date).to eq(Date.new(2026, 5, 11))
    refresh_browser_at(destination)
  end
end
