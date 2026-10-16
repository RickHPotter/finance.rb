# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscription bulk edit", type: :feature do
  let(:user) { create(:user, :random) }
  let!(:subscription) { create(:subscription, user:, context: user.main_context) }

  before { sign_in user }

  it "shows the action bar only for selected rows and updates a desktop subscription" do
    visit subscriptions_path
    expect(page).to have_css("#subscription_bulk_form", visible: :hidden)

    find("input[name='subscription_ids[]'][value='#{subscription.id}']").check
    expect(page).to have_css("#subscription_bulk_form", visible: true)
    find("#subscription_bulk_form select[name='bulk_value']:not([disabled])").select("Pause")
    click_button(I18n.t("dashboards.subscriptions.bulk.apply"))

    expect(page).to have_css("[data-id='#{subscription.id}']", text: "PAUSED")
    expect(subscription.reload).to be_paused
  end

  it "offers the same selection and clear action at a narrow viewport" do
    original_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(390, 844)
    visit subscriptions_path

    find("input[name='subscription_ids[]'][value='#{subscription.id}']").check
    expect(page).to have_css("#subscription_bulk_form", visible: true)
    click_button(I18n.t("dashboards.subscriptions.bulk.clear_selection"))
    expect(page).to have_css("#subscription_bulk_form", visible: :hidden)
  ensure
    page.driver.browser.manage.window.resize_to(original_size.width, original_size.height) if original_size
  end
end
