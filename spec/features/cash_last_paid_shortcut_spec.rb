# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash last paid shortcut", type: :feature do
  it "scrolls to the last visible paid cash row, ignoring unpaid and hidden rows" do
    sign_in create(:user, :random)
    visit donation_static_path

    page.execute_script(<<~JS)
      const fixture = document.createElement("div")
      fixture.innerHTML = `
        <div data-datatable-target="row" data-paid="true" id="paid-first"></div>
        <div data-datatable-target="row" data-paid="true" id="paid-last"></div>
        <div data-datatable-target="row" data-paid="false" id="unpaid-last"></div>
        <div hidden><div data-datatable-target="row" data-paid="true" id="hidden-paid"></div></div>`
      document.body.appendChild(fixture)
      fixture.querySelectorAll("[data-paid]").forEach(row => {
        row.scrollIntoView = () => { window.lastPaidShortcutTarget = row.id }
      })
    JS

    page.driver.browser.action.send_keys("n").perform
    expect(page.evaluate_script("window.lastPaidShortcutTarget")).to eq("paid-last")
  end
end
