# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Discount line items", type: :feature do
  it "adds a removable discount first in a cash purchase" do
    user = create(:user, :random)
    create(:user_bank_account, :random, user:)
    sign_in user
    visit new_cash_transaction_path

    find("[data-value='split']").click
    fill_in "cash_transaction_description", with: "Discount purchase"
    fill_in "transaction_price", with: "9000"
    find("[data-action='click->composite-transaction#addDiscount']").click
    discount = first("[data-composite-transaction-target~='row'][data-discount='true']")
    discount.find("input[name$='[price]']").fill_in with: "1000"
    product = first("[data-composite-transaction-target~='row'][data-discount='false']")
    product.find("input[name$='[description]']").fill_in with: "Food"
    product.find("input[name$='[price]']").fill_in with: "10000"

    expect(page).to have_css("[data-composite-transaction-target~='discountButton'][disabled]")
    expect(page).to have_text(I18n.t("transactions.composite.balanced"))
    expect(discount.find("input[name$='[category_id]']", visible: :all).value).to eq(user.categories.find_by!(category_name: "DISCOUNT").id.to_s)
    expect(discount).to have_no_css("input[name$='[entity_id]']", visible: :all)
    expect(page.all("[data-composite-transaction-target~='row']").first["data-discount"]).to eq("true")

    click_button I18n.t("actions.submit")
    expect(page).to have_current_path(cash_transactions_path, ignore_query: true)
    saved = user.cash_transactions.find_by!(description: "Discount purchase")
    expect(saved.line_items.map { |item| [ item.item_kind, item.price ] }).to contain_exactly([ "discount", 1000 ], [ "product", -10_000 ])
    visit edit_cash_transaction_path(saved)
    discount = first("[data-composite-transaction-target~='row'][data-discount='true']")
    expect(page.all("[data-composite-transaction-target~='row']").first["data-discount"]).to eq("true")

    find("[data-value='single']").click
    submitted = page.evaluate_script(<<~JS)
      Array.from(new FormData(document.querySelector("input[name='cash_transaction[split_purchase]']").form).entries())
        .filter(([name]) => name.includes('[line_items_attributes]'))
    JS
    expect(submitted.map(&:first)).to all(match(/\[(id|_destroy)\]\z/))
    expect(submitted.select { |name, _| name.end_with?("[_destroy]") }.map(&:last)).to eq(%w[1 1])
    find("[data-value='split']").click
    expect(page).to have_field("cash_transaction[line_items_attributes][0][description]", with: I18n.t("transactions.composite.discount"))
    expect(page).to have_field("cash_transaction[line_items_attributes][1][description]", with: "Food")

    discount.find("button[data-action='click->composite-transaction#removeRow']").click
    expect(page).to have_css("[data-composite-transaction-target~='discountButton']:not([disabled])")
    find("[data-value='single']").click
    find("[data-value='split']").click
    expect(page).to have_css("[data-composite-transaction-target~='row'][data-discount='true'].hidden", visible: :all)
    expect(page).to have_css("[data-composite-transaction-target~='discountButton']:not([disabled])")
  end
end
