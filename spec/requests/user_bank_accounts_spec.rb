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

    it "finds accounts with normalized text" do
      account = create(:user_bank_account, :random, user:, bank:, user_bank_account_name: "POUPÁNÇA   FÁCIL")

      get user_bank_accounts_path(search_term: "  poupanca facil ")

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.at_css("#user_bank_account_#{account.id}")).to be_present
    end
  end

  describe "[ #show ]" do
    it "renders a restorable lazy movement report and context-scoped allocation summaries" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)
      main_category = create(:category, user:, category_name: "Main Food")
      scenario_category = create(:category, user:, category_name: "Scenario Food", colour: "#4b5563")
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
      report_params = {
        from_date: "2026-04-01",
        to_date: "2026-04-30",
        granularity: "day",
        paid_state: "all",
        direction: "all"
      }
      get user_bank_account_path(user_bank_account), params: report_params

      expect(response).to have_http_status(:success)
      expect(response.body).to include(user_bank_account.user_bank_account_name)
      expect(response.body).to include("Summary")
      expect(response.body).to include("Bank account movement")
      expect(response.body).to include("Scenario Food")
      expect(response.body).to include("Scenario Entity")
      expect(response.body).not_to include("Main Food")
      expect(response.body).not_to include("Main Entity")
      expect(response.body).to include("background-color: #4b5563", "color: #ffffff")

      trend = response.parsed_body.at_css("#user_bank_account_#{user_bank_account.id}_movement")
      expect(trend["data-allocation-trend-url-value"]).to eq(user_bank_account_movement_path(user_bank_account))
      expect(trend.at_css("#user_bank_account_#{user_bank_account.id}_movement_from_date")["value"]).to eq("2026-04-01")
      expect(response.parsed_body.at_css("[data-controller~='interactive-breakdown-dashboard']")).to be_nil

      get user_bank_account_movement_path(user_bank_account), params: report_params

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig("summary", "source_count")).to be_nil
      expect(response.parsed_body.dig("summary", "income", "source_count") + response.parsed_body.dig("summary", "outcome", "source_count")).to eq(1)
      expect(response.body).not_to include("Main account transaction")
    end

    it "keeps future installments outside a bounded account report" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      assets = create(:category, user:, category_name: "ASSETS")
      gigi = create(:entity, user:, entity_name: "GIGI")
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Future assets",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: 15_949_92, paid: false),
          build(:cash_installment, number: 2, date: Date.new(2030, 3, 10), month: 3, year: 2030, price: 15_949_92, paid: false)
        ]
      )
      create(:category_transaction, transactable: transaction, category: assets)
      create(:entity_transaction, transactable: transaction, entity: gigi)

      get user_bank_account_movement_path(user_bank_account), params: { from_date: "2026-04-01", to_date: "2026-04-30" }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig("summary", "outcome", "source_count") + response.parsed_body.dig("summary", "income", "source_count")).to eq(1)
      expect(response.parsed_body.fetch("buckets").pluck("key")).to eq([ "2026-04" ])
      expect(response.body).not_to include("2030-03")
    end

    it "counts installments once when transactions have extra categories" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      assets = create(:category, user:, category_name: "ASSETS")
      lend_request = user.built_in_category("EXCHANGE")
      gigi = create(:entity, user:, entity_name: "GIGI")
      moi = user.built_in_entity("MOI")
      assets_only_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Assets only",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: 1_000, paid: false)
        ]
      )
      mixed_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Assets borrow return",
        date: Date.new(2026, 4, 11),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 2, 10), month: 1, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 2, date: Date.new(2026, 4, 10), month: 3, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 3, date: Date.new(2026, 5, 10), month: 4, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 4, date: Date.new(2026, 6, 10), month: 5, year: 2026, price: 3_000, paid: false)
        ]
      )

      create(:category_transaction, transactable: assets_only_transaction, category: assets)
      create(:category_transaction, transactable: mixed_transaction, category: assets)
      create(:category_transaction, transactable: mixed_transaction, category: lend_request)
      create(:entity_transaction, transactable: assets_only_transaction, entity: gigi)
      create(:entity_transaction, transactable: mixed_transaction, entity: gigi)
      create(:entity_transaction, transactable: mixed_transaction, entity: moi)

      get user_bank_account_movement_path(user_bank_account), params: { from_date: "2026-01-01", to_date: "2026-05-31" }

      expect(response.parsed_body.dig("summary", "net_cents")).to eq(10_000)
      expect(response.parsed_body.dig("summary", "income", "source_count")).to eq(5)
      expect(response.parsed_body.fetch("breakdowns")).to contain_exactly(
        include("key" => "ordinary", "net_cents" => 1_000),
        include("key" => "transfer", "net_cents" => 9_000)
      )
    end

    it "counts installments once when transactions have extra entities" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      assets = create(:category, user:, category_name: "ASSETS")
      lend_request = user.built_in_category("EXCHANGE")
      gigi = create(:entity, user:, entity_name: "GIGI")
      moi = user.built_in_entity("MOI")
      gigi_only_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Gigi only",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: 1_000, paid: false)
        ]
      )
      mixed_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Gigi and Moi",
        date: Date.new(2026, 4, 11),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 2, 10), month: 1, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 2, date: Date.new(2026, 4, 10), month: 3, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 3, date: Date.new(2026, 5, 10), month: 4, year: 2026, price: 2_000, paid: false),
          build(:cash_installment, number: 4, date: Date.new(2026, 6, 10), month: 5, year: 2026, price: 3_000, paid: false)
        ]
      )

      create(:category_transaction, transactable: gigi_only_transaction, category: assets)
      create(:category_transaction, transactable: mixed_transaction, category: assets)
      create(:category_transaction, transactable: mixed_transaction, category: lend_request)
      create(:entity_transaction, transactable: gigi_only_transaction, entity: gigi)
      create(:entity_transaction, transactable: mixed_transaction, entity: gigi)
      create(:entity_transaction, transactable: mixed_transaction, entity: moi)

      get user_bank_account_movement_path(user_bank_account), params: { from_date: "2026-01-01", to_date: "2026-05-31" }

      expect(response.parsed_body.dig("summary", "net_cents")).to eq(10_000)
      expect(response.parsed_body.dig("summary", "income", "source_count")).to eq(5)
      expect(response.parsed_body.fetch("breakdowns")).to contain_exactly(
        include("key" => "ordinary", "net_cents" => 1_000),
        include("key" => "transfer", "net_cents" => 9_000)
      )
    end

    it "reports an exchange allocation only in the transfer family" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      assets = create(:category, user:, category_name: "ASSETS")
      exchange = user.built_in_category("EXCHANGE")
      gigi = create(:entity, user:, entity_name: "GIGI")
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Assets exchange",
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: 1_000, paid: false)
        ]
      )

      create(:category_transaction, transactable: transaction, category: assets)
      create(:category_transaction, transactable: transaction, category: exchange)
      create(:entity_transaction, transactable: transaction, entity: gigi)

      get user_bank_account_movement_path(user_bank_account), params: { from_date: "2026-04-01", to_date: "2026-04-30" }

      expect(response.parsed_body.fetch("breakdowns")).to contain_exactly(
        include("key" => "transfer", "net_cents" => 1_000)
      )
    end
  end

  describe "[ #movement ]" do
    it "rejects invalid report state and accounts owned by another user" do
      user_bank_account = create(:user_bank_account, user:, bank:)
      foreign_account = create(:user_bank_account, :random, user: create(:user, :random))

      get user_bank_account_movement_path(user_bank_account), params: { granularity: "week" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("code" => "invalid_granularity")

      get user_bank_account_movement_path(foreign_account)
      expect(response).to have_http_status(:not_found)
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
