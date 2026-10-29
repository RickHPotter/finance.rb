# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Prepaid card corrections", type: :feature do
  it "edits a paid purchase amount and marks its installment unpaid" do
    user = create(:user, :random)
    card = create(:user_card, :random, user:, card_kind: "prepaid")
    transaction = CardTransaction.new(user:, context: user.main_context, user_card: card, date: Time.zone.today, description: "Lunch", price: -1000)
    transaction.card_installments.first.price = -1000
    transaction.build_month_year
    transaction.save!
    sign_in user

    visit edit_card_transaction_path(transaction)
    installment = find("[data-reactive-form-target='installmentWrapper']")
    expect(installment.find("[data-reactive-form-target='priceInstallmentInput']")).not_to be_readonly
    fill_in "transaction_price", with: "1200"
    installment.find("button[data-action='click->reactive-form#togglePaid']").click
    check "card_transaction_historical_correction_confirmation"
    click_button I18n.t("actions.submit")

    expect(page).to have_current_path(card_transactions_path, ignore_query: true)
    expect(transaction.reload.price).to eq(-1200)
    expect(transaction.card_installments.first).to have_attributes(price: -1200, paid: false)
  end
end
