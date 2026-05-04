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

  describe "[ #show ]" do
    it "renders a context-scoped dashboard with summary, details, and category/entity breakdowns" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)
      main_category = create(:category, user:, category_name: "Main Food")
      scenario_category = create(:category, user:, category_name: "Scenario Food")
      main_entity = create(:entity, user:, entity_name: "Main Entity")
      scenario_entity = create(:entity, user:, entity_name: "Scenario Entity")

      main_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main account transaction",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026
      )
      scenario_transaction = create(
        :cash_transaction,
        user:,
        context: scenario_context,
        user_bank_account:,
        description: "Scenario account transaction",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026
      )
      create(:category_transaction, transactable: main_transaction, category: main_category)
      create(:category_transaction, transactable: scenario_transaction, category: scenario_category)
      create(:entity_transaction, transactable: main_transaction, entity: main_entity)
      create(:entity_transaction, transactable: scenario_transaction, entity: scenario_entity)

      patch switch_context_path(scenario_context)
      get user_bank_account_path(user_bank_account)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(user_bank_account.user_bank_account_name)
      expect(response.body).to include("Summary")
      expect(response.body).to include("Details")
      expect(response.body).to include("Scenario Food")
      expect(response.body).to include("Scenario Entity")
      expect(response.body).not_to include("Main Food")
      expect(response.body).not_to include("Main Entity")
    end
  end

  describe "[ #new ]" do
    it "renders the ruby ui combobox" do
      get new_user_bank_account_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("ruby-ui--combobox")
      expect(response.body).not_to include("hw-combobox")
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
