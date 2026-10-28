# frozen_string_literal: true

require "rails_helper"

RSpec.describe "New transaction installments", type: :feature do
  let(:user) { create(:user, :random) }

  before do
    create(:user_bank_account, :random, user:)
    sign_in user
  end

  %w[cash credit prepaid debit].each do |kind|
    it "fills and permits editing the installment for a new #{kind} transaction" do
      if kind == "cash"
        visit new_cash_transaction_path
      else
        account = user.user_bank_accounts.first if kind == "debit"
        card = create(:user_card, :random, user:, card_kind: kind, user_bank_account: account)
        visit new_card_transaction_path(user_card_id: card.id)
      end

      fill_in "transaction_price", with: "12345"
      installment = find("[data-reactive-form-target='priceInstallmentInput']")
      expect(installment.value.gsub(/\D/, "").to_i).to eq(12_345)
      expect(installment).not_to be_readonly
      installment.fill_in with: "54321"
      expect(installment.value.gsub(/\D/, "").to_i).to eq(54_321)
    end
  end

  %w[cash credit].each do |kind|
    it "splits a new #{kind} transaction into multiple installments" do
      if kind == "cash"
        visit new_cash_transaction_path
      else
        card = create(:user_card, :random, user:)
        visit new_card_transaction_path(user_card_id: card.id)
      end

      fill_in "transaction_price", with: "12000"
      fill_in "#{kind == 'cash' ? 'cash' : 'card'}_installments_count", with: "2"
      expect(page).to have_css("[data-reactive-form-target='priceInstallmentInput']", count: 2)
      expect(page.all("[data-reactive-form-target='priceInstallmentInput']").map { |input| input.value.gsub(/\D/, "").to_i }).to eq([ 6000, 6000 ])
    end
  end
end
