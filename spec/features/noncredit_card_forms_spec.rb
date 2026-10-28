# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Noncredit card forms", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    @original_window_size = page.driver.browser.manage.window.size
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  after do
    page.driver.browser.manage.window.resize_to(@original_window_size.width, @original_window_size.height)
  end

  it "switches credit fields for prepaid and bank account fields for debit" do
    visit new_user_card_path

    kind = find("[data-card-kind-form-target='kind']")
    kind.find("button").click
    kind.find("label", text: I18n.t("activerecord.attributes.user_card.card_kinds.prepaid")).click
    expect(page).to have_css("[data-card-kind-form-target='creditField'].hidden", count: 4, visible: :all)
    expect(page).to have_css("[data-card-kind-form-target~='debitField'].hidden", visible: :all)

    kind.find("button").click
    kind.find("label", text: I18n.t("activerecord.attributes.user_card.card_kinds.debit")).click
    expect(page).to have_css("[data-card-kind-form-target~='debitField']:not(.hidden)")
    expect(page).to have_css("[data-card-kind-form-target~='bankAccount'] button:not([disabled])")
  end

  it "keeps a prepaid purchase at one installment on the mobile form" do
    page.driver.browser.manage.window.resize_to(390, 844)
    card = create(:user_card, :random, user:, card_kind: "prepaid")

    visit new_card_transaction_path(user_card_id: card.id)

    expect(page).to have_field("card_installments_count", with: "1", disabled: true)
    expect(page).to have_css("input[name^='card_transaction[card_installments_attributes]']", visible: :all)
  end

  it "filters the card list by kind and returns to all cards" do
    create(:user_card, :random, user:, user_card_name: "Credit card")
    create(:user_card, :random, user:, card_kind: "prepaid", user_card_name: "Prepaid card")
    visit user_cards_path

    filter = find("#user_cards_kind_filter")
    filter.find("button").click
    filter.find("label", text: I18n.t("activerecord.attributes.user_card.card_kinds.prepaid")).click
    expect(page).to have_text("Prepaid card")
    expect(page).to have_no_text("Credit card")

    filter = find("#user_cards_kind_filter")
    filter.find("button").click
    filter.find("label", text: I18n.t("actions.all"), exact_text: true).click
    expect(page).to have_text("Credit card")
  end
end
