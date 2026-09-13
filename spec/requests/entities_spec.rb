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

    it "finds entities with normalized text" do
      entity = create(:entity, user:, entity_name: "CRÍSTIAN   PENS")

      get entities_path(search_term: "  cristian pens ")

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.at_css("#show_entity_#{entity.id}")).to be_present
    end
  end

  describe "[ #show ]" do
    it "renders entity details with a restorable lazy trend and context-scoped report data" do
      entity = create(:entity, user:, entity_name: "GIGI")
      scenario_context = create(:context, user:, name: "Scenario Entity", source_context: user.main_context)
      scenario_category = create(
        :category,
        user:,
        category_name: "Scenario Category",
        colour: "#ffffff",
        text_colour_mode: "manual",
        text_colour: "#767676"
      )
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
      report_params = {
        from_date: "2026-04-01",
        to_date: "2026-04-30",
        granularity: "day",
        paid_state: "all",
        direction: "outcome"
      }
      get entity_path(entity), params: report_params

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Details")
      expect(response.body).to include(Category.model_name.human(count: 2))
      expect(response.body).to include("User Bank Accounts")
      expect(response.body).to include("User Cards")

      trend = response.parsed_body.at_css("[data-controller~='allocation-trend']")
      expect(trend).to be_present
      expect(trend["data-allocation-trend-url-value"]).to eq(entity_trend_path(entity))
      expect(trend.at_css("#entity_#{entity.id}_trend_from_date")["value"]).to eq("2026-04-01")
      expect(trend.at_css("#entity_#{entity.id}_trend_to_date")["value"]).to eq("2026-04-30")
      expect(trend.at_css("#entity_#{entity.id}_trend_granularity option[selected]")["value"]).to eq("day")
      expect(trend.at_css("#entity_#{entity.id}_trend_direction option[selected]")["value"]).to eq("outcome")
      counterpart_payload = pie_payloads(response.body).fetch("counterpart")
      expect(counterpart_payload.fetch("filterOptions").pluck("label")).to include("Bank Account: 99PAY", "User Card: 99PAY")
      expect(counterpart_payload.fetch("entries").pluck("name")).to include("Scenario Category")
      expect(counterpart_payload.to_json).not_to include("Main Category")
      scenario_counterpart = counterpart_payload.fetch("entries").find { |entry| entry.fetch("name") == "Scenario Category" }
      expect(scenario_counterpart).to include(
        "background" => "#ffffff",
        "foreground" => "#767676"
      )

      get entity_trend_path(entity), params: report_params

      payload = response.parsed_body
      expect(payload.dig("summary", "net_cents")).to eq(-8_000)
      expect(payload.fetch("breakdowns").pluck("label")).to all(include("Scenario Category"))
      expect(payload.to_json).not_to include("Main Category")
      scenario_entry = payload.fetch("breakdowns").find { |entry| entry.fetch("label") == "Scenario Category" }
      expect(scenario_entry).to include(
        "background" => "#ffffff",
        "foreground" => "#767676"
      )
    end

    it "sums transactions with duplicate prices independently" do
      entity = create(:entity, user:, entity_name: "DUPLICATE PRICES")
      user_card = user.user_cards.find_by!(user_card_name: "99PAY")
      cash_transactions = create_list(:cash_transaction, 2, user:, context: user.main_context, user_bank_account:, price: -2_000)
      card_transactions = create_list(:card_transaction, 2, user:, context: user.main_context, user_card:, price: -3_000)
      cash_transactions.each { |transaction| create(:entity_transaction, transactable: transaction, entity:) }
      card_transactions.each { |transaction| create(:entity_transaction, transactable: transaction, entity:) }

      get entity_path(entity)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("R$ -40.00", "R$ -60.00")
    end
  end

  describe "[ #new ]" do
    it "offers the Magnific people avatars with their attribution" do
      get new_entity_path

      expect(response).to have_http_status(:success)
      document = response.parsed_body
      %w[30 31 32 33].each do |number|
        expect(document.at_css("img[src*='avatars/people/#{number}']")).to be_present
      end
      credit = document.at_css("a[href='https://www.flaticon.com/authors/magnific']")
      expect(credit).to be_present
      expect(credit.text).to include("Magnific", "Flaticon")
    end
  end

  describe "[ #trend ]" do
    it "returns a context-scoped entity trend payload" do
      entity = create(:entity, user:, entity_name: "REPORT ANA")
      transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account:, date: Date.new(2026, 7, 10), month: 7, year: 2026,
                                              price: 2_500)
      create(:entity_transaction, transactable: transaction, entity:)

      get entity_trend_path(entity), params: { from_date: "2026-07-01", to_date: "2026-07-31" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to include(
        "resource" => { "type" => "Entity", "id" => entity.id, "label" => "REPORT ANA" },
        "summary" => include("net_cents" => 2_500)
      )
    end

    it "rejects invalid report state and entities owned by another user" do
      entity = create(:entity, user:)
      foreign_entity = create(:entity, user: create(:user, :random))

      get entity_trend_path(entity), params: { granularity: "week" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("code" => "invalid_granularity")

      get entity_trend_path(foreign_entity)
      expect(response).to have_http_status(:not_found)
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
