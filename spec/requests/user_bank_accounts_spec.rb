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
      expect(response.body).to include("Category Interactive Dashboard")
      expect(response.body).to include("Entity Interactive Dashboard")
      expect(response.body).to include("Scenario Food")
      expect(response.body).to include("Scenario Entity")
      expect(response.body).not_to include("Main Food")
      expect(response.body).not_to include("Main Entity")
    end

    it "includes future installment points in the interactive category dashboard payload" do
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

      get user_bank_account_path(user_bank_account)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("ASSETS")
      expect(response.body).to include("GIGI")
      expect(response.body).to include("2026-04-01")
      expect(response.body).to include("2030-03-01")
    end

    it "keeps only-category dashboard groups strict when transactions have extra categories" do
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

      get user_bank_account_path(user_bank_account)

      category_payload = interactive_dashboard_payloads(response.body).fetch("category")
      assets_entry = category_payload.fetch("items").find { |category| category.fetch("name") == "ASSETS" }
      only_assets_group = assets_entry.fetch("groups").find { |group| group.fetch("id") == "__all__" }
      mixed_assets_group = assets_entry.fetch("groups").find { |group| group.fetch("label") == "+ LEND REQUEST" }
      gigi_moi_entity = mixed_assets_group.fetch("secondaryItems").find { |entity| entity.fetch("name") == "GIGI / MOI" }

      expect(only_assets_group.fetch("memberIds")).to eq([ assets.id.to_s ])
      expect(only_assets_group.fetch("secondaryItems").pluck("name")).not_to include("GIGI / MOI")
      expect(mixed_assets_group.fetch("memberIds")).to eq([ assets.id, lend_request.id ].sort.map(&:to_s))
      expect(only_assets_group.fetch("secondaryItems").sum { |entity| entity.fetch("total") }).to eq(1_000)
      expect(mixed_assets_group.fetch("secondaryItems").sum { |entity| entity.fetch("total") }).to eq(9_000)
      expect(gigi_moi_entity.fetch("memberIds").sort).to eq([ gigi.id, moi.id ].sort.map(&:to_s))
      expect(gigi_moi_entity.fetch("points").pluck("x")).to eq(%w[2026-02-01 2026-04-01 2026-05-01 2026-06-01])
    end

    it "keeps only-entity dashboard groups strict when transactions have extra entities" do
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

      get user_bank_account_path(user_bank_account)

      entity_payload = interactive_dashboard_payloads(response.body).fetch("entity")
      gigi_entry = entity_payload.fetch("items").find { |entity| entity.fetch("name") == "GIGI" }
      only_gigi_group = gigi_entry.fetch("groups").find { |group| group.fetch("id") == "__all__" }
      mixed_gigi_group = gigi_entry.fetch("groups").find { |group| group.fetch("label") == "+ MOI" }
      assets_lend_request_category = mixed_gigi_group.fetch("secondaryItems").find { |category| category.fetch("name") == "ASSETS / LEND REQUEST" }

      expect(only_gigi_group.fetch("memberIds")).to eq([ gigi.id.to_s ])
      expect(only_gigi_group.fetch("secondaryItems").pluck("name")).not_to include("ASSETS / LEND REQUEST")
      expect(mixed_gigi_group.fetch("memberIds")).to eq([ gigi.id, moi.id ].sort.map(&:to_s))
      expect(only_gigi_group.fetch("secondaryItems").sum { |category| category.fetch("total") }).to eq(1_000)
      expect(mixed_gigi_group.fetch("secondaryItems").sum { |category| category.fetch("total") }).to eq(9_000)
      expect(assets_lend_request_category.fetch("memberIds").sort).to eq([ assets.id, lend_request.id ].sort.map(&:to_s))
      expect(assets_lend_request_category.fetch("points").pluck("x")).to eq(%w[2026-02-01 2026-04-01 2026-05-01 2026-06-01])
    end

    it "allows built-in exchange as a category group but not as a selectable base category" do
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

      get user_bank_account_path(user_bank_account)

      payload = interactive_dashboard_payloads(response.body).fetch("category")
      category_names = payload.fetch("items").pluck("name")
      assets_entry = payload.fetch("items").find { |category| category.fetch("name") == "ASSETS" }

      expect(category_names).to include("ASSETS")
      expect(category_names).not_to include("LEND REQUEST")
      expect(assets_entry.fetch("groups").pluck("label")).to include("+ LEND REQUEST")
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

  def interactive_dashboard_payloads(body)
    body.scan(/data-interactive-breakdown-dashboard-data-value="([^"]+)"/).to_h do |(value)|
      payload = JSON.parse(CGI.unescapeHTML(value))
      [ payload.fetch("primaryKind"), payload ]
    end
  end
end
