# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserBankAccounts", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get user_bank_accounts_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a user bank account" do
      expect do
        post user_bank_accounts_path, params: {
          user_bank_account: {
            user_bank_account_name: "PIX",
            agency_number: "1234",
            account_number: "987654",
            balance: 50_000,
            active: true,
            bank_id: bank.id,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(UserBankAccount, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      user_bank_account = create(:user_bank_account, user:, bank:)

      patch user_bank_account_path(user_bank_account), params: {
        user_bank_account: {
          user_bank_account_name: "Main Account",
          agency_number: user_bank_account.agency_number,
          account_number: user_bank_account.account_number,
          balance: user_bank_account.balance,
          active: user_bank_account.active,
          bank_id: bank.id,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(user_bank_account.reload.user_bank_account_name).to eq("Main Account")
    end
  end

  describe "[ #destroy ]" do
    it "destroys a bank account without cash transactions" do
      user_bank_account = create(:user_bank_account, user:, bank:)

      expect do
        delete user_bank_account_path(user_bank_account), headers: turbo_stream_headers
      end.to change(UserBankAccount, :count).by(-1)
    end
  end
end
