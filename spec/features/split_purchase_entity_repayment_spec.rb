# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Split purchase entity repayment", type: :feature do
  let!(:user) { create(:user, :random) }
  let!(:friend) { create(:entity, user:, entity_name: "Friend", entity_user: create(:user, :random)) }
  let!(:exchange_category) { user.categories.find_by!(category_name: "EXCHANGE", built_in: true) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
    visit new_cash_transaction_path
    find("[data-value='split']").click
  end

  it "clicking Automatic sets repayment and automatically assigns EXCHANGE category" do
    fill_in "cash_transaction_description", with: "Shared dinner"
    fill_in "transaction_price", with: "5000"

    row = first("[data-composite-transaction-target~='row'][data-discount='false']")
    row.find("input[name$='[description]']").fill_in with: "Dinner"
    row.find("input[name$='[price]']").fill_in with: "5000"

    entity_picker = row.find("[data-composite-entity-modal-target='entityPicker']")
    entity_picker.click
    find("input[name*='[entity_id]'][value='#{friend.id}']", visible: :all).find(:xpath, "..").click

    row.find("[data-composite-entity-modal-target~='trigger'] button").click

    within("[data-composite-entity-modal-target~='content']") do
      find("button[data-action~='click->entity-transaction#automaticLineItemRepayment']").click
      expect(find("input[name*='[price_to_be_returned]']").value).to match(/50[.,]00/)
    end

    category_radio = row.find("input[name$='[category_id]'][value='#{exchange_category.id}']", visible: :all)
    expect(category_radio).to be_checked

    category_trigger = row.find(".combobox-shell", match: :first).find("button[data-ruby-ui--combobox-target='trigger']")
    expect(category_trigger).to have_text(exchange_category.name)
  end

  it "manually typing a return price automatically assigns EXCHANGE category" do
    fill_in "cash_transaction_description", with: "Shared lunch"
    fill_in "transaction_price", with: "4000"

    row = first("[data-composite-transaction-target~='row'][data-discount='false']")
    row.find("input[name$='[description]']").fill_in with: "Lunch"
    row.find("input[name$='[price]']").fill_in with: "4000"

    entity_picker = row.find("[data-composite-entity-modal-target='entityPicker']")
    entity_picker.click
    find("input[name*='[entity_id]'][value='#{friend.id}']", visible: :all).find(:xpath, "..").click

    row.find("[data-composite-entity-modal-target~='trigger'] button").click

    within("[data-composite-entity-modal-target~='content']") do
      return_input = find("input[name*='[price_to_be_returned]']")
      return_input.fill_in with: "4000"
    end

    category_radio = row.find("input[name$='[category_id]'][value='#{exchange_category.id}']", visible: :all)
    expect(category_radio).to be_checked

    category_trigger = row.find(".combobox-shell", match: :first).find("button[data-ruby-ui--combobox-target='trigger']")
    expect(category_trigger).to have_text(exchange_category.name)
  end
end
