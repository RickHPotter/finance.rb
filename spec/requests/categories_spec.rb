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

    it "renders category links with the complete resolved pair" do
      category = create(:category, user:, category_name: "Dark category", colour: "#4b5563")

      get categories_path

      document = response.parsed_body
      badge = document.at_css("#show_category_#{category.id}")

      expect(badge["style"]).to include("background-color: #4b5563", "color: #ffffff")
      expect(badge["class"]).not_to include("hover:opacity")
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

  describe "[ #new ]" do
    it "renders the accessible colour controls and complete live preview surface" do
      get new_category_path

      document = response.parsed_body
      form = document.at_css("form[data-controller~='category-colour-preview']")

      expect(response).to have_http_status(:success)
      expect(form).to be_present
      expect(form.at_css("#category_text_colour_mode_automatic[checked]")).to be_present
      expect(form.at_css("#category_text_colour_mode_manual")).to be_present
      expect(form.at_css("[data-category-colour-preview-target='backgroundInput']")).to be_present
      expect(form.at_css("[data-category-colour-preview-target='foregroundInput']")).to be_present
      expect(form.at_css("[data-category-colour-preview-target='manualFields'][aria-hidden='true']")).to be_present
      expect(form.css("[data-category-colour-preview-target='preview']").size).to eq(7)
      expect(form.css("[data-preview-state]").pluck("data-preview-state")).to contain_exactly(
        "normal", "normal", "normal", "hover", "focus", "selected", "disabled"
      )
    end
  end

  describe "[ #edit ]" do
    it "renders persisted manual colours without hiding the foreground controls" do
      category = create(:category, user:, colour: "#000000", text_colour_mode: "manual", text_colour: "#ffffff")

      get edit_category_path(category)

      document = response.parsed_body
      form = document.at_css("form[data-controller~='category-colour-preview']")

      expect(response).to have_http_status(:success)
      expect(form.at_css("#category_text_colour_mode_manual[checked]")).to be_present
      expect(form.at_css("[data-category-colour-preview-target='manualFields'][aria-hidden='false']")).to be_present
      expect(form.at_css("input[name='category[text_colour]']")["value"]).to eq("#ffffff")
      expect(form.at_css("[data-category-colour-preview-target='ratio']").text).to eq("21.00:1")
    end
  end

  describe "[ #create ]" do
    it "creates a category with a normalized manual text-colour preference" do
      expect do
        post categories_path, params: {
          category: {
            category_name: "Travel",
            colour: "FFFFFF",
            text_colour_mode: "manual",
            text_colour: "767676",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(Category, :count).by(1)

      category = user.categories.find_by!(category_name: "Travel")
      expect(category.colour).to eq("#ffffff")
      expect(category.text_colour_mode).to eq("manual")
      expect(category.text_colour).to eq("#767676")
    end

    it "rejects an inaccessible manual colour while retaining inputs and stacking concrete feedback" do
      expect do
        post categories_path, params: {
          category: {
            category_name: "Unreadable",
            colour: "#ffffff",
            text_colour_mode: "manual",
            text_colour: "#777777",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.not_to change(Category, :count)

      document = Nokogiri::HTML5.fragment(response.body)
      rendered_form = document.at_css("turbo-stream[action='replace'][target='new_category'] template form")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("4.48:1", "#000000")
      expect(document.css("turbo-stream[action='update'][target='notification']").size).to eq(1)
      expect(document.css("turbo-stream[action='append'][target='notification']")).not_to be_empty
      expect(document.at_css("turbo-stream[target='center_container']")).to be_nil
      expect(rendered_form).to be_present
      expect(rendered_form.at_css("#category_text_colour_mode_manual[checked]")).to be_present
      expect(rendered_form.at_css("input[name='category[colour]']")["value"]).to eq("#ffffff")
      expect(rendered_form.at_css("input[name='category[text_colour]']")["value"]).to eq("#777777")
    end

    it "retains malformed colour input without interpolating it into inline styles" do
      post categories_path, params: {
        category: {
          category_name: "Malformed",
          colour: "#abcd",
          text_colour_mode: "automatic",
          active: true,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      document = Nokogiri::HTML5.fragment(response.body)
      rendered_form = document.at_css("turbo-stream[action='replace'][target='new_category'] template form")

      expect(response).to have_http_status(:unprocessable_content)
      expect(document.at_css("turbo-stream[target='center_container']")).to be_nil
      expect(rendered_form).to be_present
      expect(rendered_form.at_css("input[name='category[colour]']")["value"]).to eq("#abcd")
      expect(rendered_form.css("[style]").pluck("style")).not_to include(a_string_including("#abcd"))
    end
  end

  describe "[ #update ]" do
    it "updates the record and clears a previous manual foreground in automatic mode" do
      category = create(:category, user:, colour: "#000000", text_colour_mode: "manual", text_colour: "#ffffff")

      patch category_path(category), params: {
        category: {
          category_name: "Updated Category",
          colour: category.colour,
          text_colour_mode: "automatic",
          text_colour: "#ffffff",
          active: category.active,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      category.reload
      expect(category.category_name).to eq("Updated Category")
      expect(category.text_colour_mode).to eq("automatic")
      expect(category.text_colour).to be_nil
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
