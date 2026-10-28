# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash exchange intent", type: :feature do
  it "shows the exchange type combobox for a friend and accepts a choice" do
    user = create(:user, :random)
    friend = create(:entity, user:, entity_name: "Friend", entity_user: create(:user, :random))
    create(:user_bank_account, :random, user:)
    sign_in user
    visit new_cash_transaction_path

    entity = find("#cash_transaction_entity_combobox")
    entity.find("button").click
    entity.find("input[value='#{friend.id}']", visible: :all).find(:xpath, "..").click
    page.execute_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('#transaction_form'), " \
                        "'reactive-form')._insertExchangeCategory()")

    intent = find("[data-reactive-form-target='exchangeIntentWrapper']")
    intent.find("button").click
    intent.find("label", text: I18n.t("activerecord.attributes.cash_transaction.friend_notification_intents.loan"), exact_text: true).click
    expect(intent).to have_css("input[value='loan']:checked", visible: :all)
  end
end
