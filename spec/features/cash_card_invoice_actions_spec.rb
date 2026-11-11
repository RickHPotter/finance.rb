# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash card invoice actions", type: :feature do
  it "changes an unpaid card invoice date without paying it" do
    user = create(:user, :random)
    card = create(:user_card, :random, user:)
    date = Time.zone.today.next_month
    purchase = create(:card_transaction, user:, user_card: card, context: user.main_context, date:, price: -1000,
                                         card_installments: [ build(:card_installment, number: 1, date:, price: -1000, paid: false) ])
    invoice = purchase.card_installments.first.cash_transaction
    installment = invoice.cash_installments.first
    new_date = installment.date.to_date + 2.days
    sign_in user

    visit cash_transactions_path(all_month_years: true)
    find("#cash_installment_actions_#{installment.id}").click
    find("button[data-modal-toggle='cashInstallmentDateModal_#{installment.id}']").click

    within("#cashInstallmentDateModal_#{installment.id}") do
      page.execute_script(<<~JS, "cash_installment_#{installment.id}_change_date_date_input", new_date.iso8601)
        const input = document.getElementById(arguments[0])
        input.value = arguments[1]
        input.dispatchEvent(new Event("input", { bubbles: true }))
        input.dispatchEvent(new Event("change", { bubbles: true }))
      JS
      click_button I18n.t("confirmation.confirm")
    end

    expect(page).to have_css("#notification-content")
    expect(installment.reload.date.to_date).to eq(new_date)
    expect(installment).not_to be_paid
    expect(invoice.reload).not_to be_paid
  end

  it "pays part of an invoice in advance from its cash-row menu" do
    user = create(:user, :random)
    card = create(:user_card, :random, user:)
    date = Time.zone.today.next_month
    purchase = create(:card_transaction, user:, user_card: card, context: user.main_context, date:, price: -1000,
                                         card_installments: [ build(:card_installment, number: 1, date:, price: -1000, paid: false) ])
    invoice = purchase.card_installments.first.cash_transaction
    installment = invoice.cash_installments.first
    modal_id = "cardTransactionModal_#{card.id}_#{invoice.month}_#{invoice.year}"
    sign_in user

    visit cash_transactions_path(all_month_years: true)
    find("#cash_installment_actions_#{installment.id}").click
    find("button[data-modal-toggle='#{modal_id}']").click
    within("##{modal_id}") do
      fill_in "transaction_price", with: "200"
      click_button I18n.t("confirmation.confirm")
    end

    expect(page).to have_css("#notification-content", text: CardTransaction.model_name.human)
    expect(user.main_context.card_transactions.order(:id).last.advance_cash_transaction.price).to eq(-200)
    expect(installment.reload).not_to be_paid
  end
end
