# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Month year selector", type: :feature do
  it "deactivates all other month-year buttons and keeps only the Shift-clicked month active" do
    sign_in create(:user, :random)
    visit cash_transactions_path

    page.execute_script(<<~JS)
      const controller = document.querySelector("[data-controller='month-year-selector']")
      const form = document.getElementById(controller.dataset.formId)
      window.__monthSelectorSubmits = 0
      form.requestSubmit = () => { window.__monthSelectorSubmits += 1 }
    JS

    jan = find("[data-month-year-selector-target='monthYear'][data-month-year='#{Date.current.year}01']", visible: :all)
    feb = find("[data-month-year-selector-target='monthYear'][data-month-year='#{Date.current.year}02']", visible: :all)
    mar = find("[data-month-year-selector-target='monthYear'][data-month-year='#{Date.current.year}03']", visible: :all)

    # Normal clicks to activate Jan and Feb
    jan.click unless jan["data-active"]
    feb.click unless feb["data-active"]
    expect(JSON.parse(find("[data-month-year-selector-target='monthYears']", visible: :all).value)).to include(
      "#{Date.current.year}01".to_i,
      "#{Date.current.year}02".to_i
    )

    # Shift + click on an inactive button (Mar) deactivates Jan & Feb and activates Mar
    page.driver.browser.action.key_down(:shift).click(mar.native).key_up(:shift).perform

    expect(JSON.parse(find("[data-month-year-selector-target='monthYears']", visible: :all).value)).to eq([ "#{Date.current.year}03".to_i ])
    expect(jan["data-active"]).to be_nil
    expect(feb["data-active"]).to be_nil
    expect(mar["data-active"]).to eq("true")

    submits_before = page.evaluate_script("window.__monthSelectorSubmits")

    # Shift + click on the already-sole-active button (Mar) does nothing and does not resubmit
    page.driver.browser.action.key_down(:shift).click(mar.native).key_up(:shift).perform

    expect(JSON.parse(find("[data-month-year-selector-target='monthYears']", visible: :all).value)).to eq([ "#{Date.current.year}03".to_i ])
    expect(page.evaluate_script("window.__monthSelectorSubmits")).to eq(submits_before)

    # Activate Feb too, then Shift + click on already-active Feb to deactivate Mar and keep only Feb
    feb.click
    page.driver.browser.action.key_down(:shift).click(feb.native).key_up(:shift).perform

    expect(JSON.parse(find("[data-month-year-selector-target='monthYears']", visible: :all).value)).to eq([ "#{Date.current.year}02".to_i ])
    expect(mar["data-active"]).to be_nil
    expect(feb["data-active"]).to eq("true")
  end

  it "shows a desktop Shift+click hint when deactivating the only active month or narrowing multiple down to one, but not on Select All" do
    user = create(:user, :random)
    create(:cash_transaction, user:, context: user.main_context, date: Date.new(Date.current.year, 1, 10))
    create(:cash_transaction, user:, context: user.main_context, date: Date.new(Date.current.year, 2, 10))
    sign_in user
    visit cash_transactions_path

    page.execute_script(<<~JS)
      const controller = document.querySelector("[data-controller='month-year-selector']")
      const form = document.getElementById(controller.dataset.formId)
      form.requestSubmit = () => {}
      window.matchMedia = () => ({ matches: true })
    JS

    hint = I18n.t("month_year_selector.solo_hint")
    jan = find("[data-month-year-selector-target='monthYear'][data-month-year='#{Date.current.year}01']", visible: :all)
    feb = find("[data-month-year-selector-target='monthYear'][data-month-year='#{Date.current.year}02']", visible: :all)

    # Ensure only Jan is active, then deactivate Jan (1 -> 0) => shows hint
    page.driver.browser.action.key_down(:shift).click(jan.native).key_up(:shift).perform
    jan.click
    expect(page).to have_css("turbo-frame#notification", text: hint)

    # Dismiss notification, activate Jan & Feb, then deactivate Jan (2 -> 1) => shows hint
    find("#notification-close").click
    expect(page).to have_no_css("#notification-content")
    jan.click
    feb.click
    jan.click
    expect(page).to have_css("turbo-frame#notification", text: hint)

    # Dismiss notification, then use Select All => does NOT show hint
    find("#notification-close").click
    expect(page).to have_no_css("#notification-content")
    find("[data-action='click->month-year-selector#selectAll']").click
    expect(page).to have_no_css("turbo-frame#notification", text: hint)

    # Non-desktop (pointer: coarse) => does NOT show hint when deactivating
    page.execute_script("window.matchMedia = () => ({ matches: false })")
    page.driver.browser.action.key_down(:shift).click(jan.native).key_up(:shift).perform
    jan.click
    expect(page).to have_no_css("turbo-frame#notification", text: hint)
  end
end
