# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Noncredit card forms", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  it "switches credit fields for prepaid and bank account fields for debit" do
    visit new_user_card_path

    kind = find("select[name='user_card[card_kind]']")
    kind.select(I18n.t("activerecord.attributes.user_card.card_kinds.prepaid"))
    expect(page).to have_css("[data-card-kind-form-target='creditField'].hidden", count: 4, visible: :all)
    expect(page).to have_css("[data-card-kind-form-target='debitField'].hidden", visible: :all)

    kind.select(I18n.t("activerecord.attributes.user_card.card_kinds.debit"))
    expect(page).to have_css("[data-card-kind-form-target='debitField']:not(.hidden)")
    expect(page).to have_select("user_card[user_bank_account_id]", visible: true)
  end

  it "keeps a prepaid purchase at one installment on the mobile form" do
    page.driver.browser.manage.window.resize_to(390, 844)
    card = create(:user_card, :random, user:, card_kind: "prepaid")

    visit new_card_transaction_path(user_card_id: card.id)

    expect(page).to have_field("card_installments_count", with: "1", disabled: true)
    expect(page).to have_css("input[name^='card_transaction[card_installments_attributes]']", visible: :all)
  end
end
