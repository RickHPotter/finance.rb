# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities", type: :request do
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
      get entities_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #show ]" do
    it "renders entity details and the pie sections scoped to the current context" do
      entity = create(:entity, user:, entity_name: "GIGI")
      scenario_context = create(:context, user:, name: "Scenario Entity", source_context: user.main_context)
      scenario_category = create(:category, user:, category_name: "Scenario Category")
      main_category = create(:category, user:, category_name: "Main Category")
      user_card = user.user_cards.find_by!(user_card_name: "99PAY")

      main_cash = create(:cash_transaction, user:, context: user.main_context, user_bank_account:, description: "Main cash", date: Date.new(2026, 4, 10), month: 4,
                                            year: 2026, price: -1_500)
      main_card = create(:card_transaction, user:, context: user.main_context, user_card:, description: "Main card", date: Date.new(2026, 4, 10), month: 4,
                                            year: 2026, price: -2_500)
      scenario_cash = create(:cash_transaction, user:, context: scenario_context, user_bank_account:, description: "Scenario cash", date: Date.new(2026, 4, 10),
                                                month: 4, year: 2026, price: -3_500)
      scenario_card = create(:card_transaction, user:, context: scenario_context, user_card:, description: "Scenario card", date: Date.new(2026, 4, 10), month: 4,
                                                year: 2026, price: -4_500)

      create(:entity_transaction, transactable: main_cash, entity:)
      create(:entity_transaction, transactable: main_card, entity:)
      create(:entity_transaction, transactable: scenario_cash, entity:)
      create(:entity_transaction, transactable: scenario_card, entity:)
      create(:category_transaction, transactable: main_cash, category: main_category)
      create(:category_transaction, transactable: main_card, category: main_category)
      create(:category_transaction, transactable: scenario_cash, category: scenario_category)
      create(:category_transaction, transactable: scenario_card, category: scenario_category)

      patch switch_context_path(scenario_context)
      get entity_path(entity)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Details")
      expect(response.body).to include("Scenario Category")
      expect(response.body).not_to include("Main Category")
      expect(response.body).to include("User Bank Accounts")
      expect(response.body).to include("User Cards")

      counterpart_payload = pie_payloads(response.body).fetch("counterpart")
      expect(counterpart_payload.fetch("filterOptions").pluck("label")).to include("Bank Account: 99PAY", "User Card: 99PAY")
      expect(counterpart_payload.fetch("entries").pluck("name")).to include("Scenario Category")
    end
  end

  describe "[ #create ]" do
    it "creates an entity" do
      expect do
        post entities_path, params: {
          entity: {
            entity_name: "Luis",
            avatar_name: "people/0.png",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(Entity, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      entity = create(:entity, user:)

      patch entity_path(entity), params: {
        entity: {
          entity_name: "Updated Entity",
          avatar_name: entity.avatar_name,
          active: entity.active,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(entity.reload.entity_name).to eq("Updated Entity")
    end

    it "does not deactivate a built-in entity" do
      entity = user.built_in_entity

      patch entity_path(entity), params: {
        entity: {
          entity_name: entity.entity_name,
          avatar_name: entity.avatar_name,
          active: false,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(entity.reload.active).to be(true)
    end
  end

  describe "[ #destroy ]" do
    it "destroys an entity without transactions" do
      entity = create(:entity, user:)

      expect do
        delete entity_path(entity), headers: turbo_stream_headers
      end.to change(Entity, :count).by(-1)
    end

    it "does not destroy a built-in entity" do
      entity = user.built_in_entity

      expect do
        delete entity_path(entity), headers: turbo_stream_headers
      end.not_to change(Entity, :count)
    end
  end

  def pie_payloads(body)
    body.scan(/data-pie-breakdown-chart-data-value="([^"]+)"/).to_h do |(value)|
      payload = JSON.parse(CGI.unescapeHTML(value))
      [ payload.fetch("kind"), payload ]
    end
  end
end
