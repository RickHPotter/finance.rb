# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fiscal receipt import", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  it "prefills an unsaved cash split purchase from fiscal XML" do
    visit new_cash_transaction_path
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    find("[data-action='click->fiscal-import#importFile']").click

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    expect(page).to have_field("cash_transaction[description]", with: "Mercado Exemplo")
    expect(page).to have_field("cash_transaction[price]", with: "-R$ 19.75")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CashTransaction.where(description: "Mercado Exemplo")).not_to exist
  end

  it "prefills an unsaved card split purchase from fiscal XML" do
    create(:user_card, :random, user:)
    visit new_card_transaction_path
    find("[data-fiscal-import-target='file']", visible: :all).attach_file(Rails.root.join("spec/fixtures/files/fiscal_receipt.xml"))
    find("[data-action='click->fiscal-import#importFile']").click

    expect(page).to have_css("[data-composite-transaction-target~='row']:not(.hidden)", count: 2)
    expect(page).to have_field("card_transaction[price]", with: "-R$ 19.75")
    descriptions = all("[data-composite-transaction-target~='row']:not(.hidden) input[name$='[description]']").map(&:value)
    expect(descriptions).to eq(%w[Arroz Feijao])
    expect(CardTransaction.where(description: "Mercado Exemplo")).not_to exist
  end
end
