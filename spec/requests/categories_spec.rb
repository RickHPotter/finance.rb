# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_bank_account) { create(:user_bank_account, user:, bank:, user_bank_account_name: "99PAY") }

  before do
    create(:user_card, :random, user:, card:, user_card_name: "99PAY")
    sign_in user
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get categories_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #show ]" do
    it "renders category details and the pie sections scoped to the current context" do
      category = create(:category, user:, category_name: "TRAVEL")
      scenario_context = create(:context, user:, name: "Scenario Category", source_context: user.main_context)
      scenario_entity = create(:entity, user:, entity_name: "Scenario Entity")
      main_entity = create(:entity, user:, entity_name: "Main Entity")
      user_card = user.user_cards.find_by!(user_card_name: "99PAY")

      main_cash = create(:cash_transaction, user:, context: user.main_context, user_bank_account:, description: "Main cash", date: Date.new(2026, 4, 10), month: 4,
                                            year: 2026, price: -1_500)
      main_card = create(:card_transaction, user:, context: user.main_context, user_card:, description: "Main card", date: Date.new(2026, 4, 10), month: 4,
                                            year: 2026, price: -2_500)
      scenario_cash = create(:cash_transaction, user:, context: scenario_context, user_bank_account:, description: "Scenario cash", date: Date.new(2026, 4, 10),
                                                month: 4, year: 2026, price: -3_500)
      scenario_card = create(:card_transaction, user:, context: scenario_context, user_card:, description: "Scenario card", date: Date.new(2026, 4, 10), month: 4,
                                                year: 2026, price: -4_500)

      create(:category_transaction, transactable: main_cash, category:)
      create(:category_transaction, transactable: main_card, category:)
      create(:category_transaction, transactable: scenario_cash, category:)
      create(:category_transaction, transactable: scenario_card, category:)
      create(:entity_transaction, transactable: main_cash, entity: main_entity)
      create(:entity_transaction, transactable: main_card, entity: main_entity)
      create(:entity_transaction, transactable: scenario_cash, entity: scenario_entity)
      create(:entity_transaction, transactable: scenario_card, entity: scenario_entity)

      patch switch_context_path(scenario_context)
      get category_path(category)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Details")
      expect(response.body).to include("Scenario Entity")
      expect(response.body).not_to include("Main Entity")
      expect(response.body).to include("User Bank Accounts")
      expect(response.body).to include("User Cards")

      counterpart_payload = pie_payloads(response.body).fetch("counterpart")
      expect(counterpart_payload.fetch("filterOptions").pluck("label")).to include("Bank Account: 99PAY", "User Card: 99PAY")
      expect(counterpart_payload.fetch("entries").pluck("name")).to include("Scenario Entity")
    end
  end

  describe "[ #create ]" do
    it "creates a category" do
      expect do
        post categories_path, params: {
          category: {
            category_name: "Travel",
            colour: "#123456",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(Category, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      category = create(:category, user:)

      patch category_path(category), params: {
        category: {
          category_name: "Updated Category",
          colour: category.colour,
          active: category.active,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(category.reload.category_name).to eq("Updated Category")
    end
  end

  describe "[ #destroy ]" do
    it "destroys a category without transactions" do
      category = create(:category, user:)

      expect do
        delete category_path(category), headers: turbo_stream_headers
      end.to change(Category, :count).by(-1)
    end
  end

  def pie_payloads(body)
    body.scan(/data-pie-breakdown-chart-data-value="([^"]+)"/).to_h do |(value)|
      payload = JSON.parse(CGI.unescapeHTML(value))
      [ payload.fetch("kind"), payload ]
    end
  end
end
