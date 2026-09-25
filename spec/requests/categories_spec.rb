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

    it "finds categories with normalized text" do
      category = create(:category, user:, category_name: "CRÍSTIAN   PENS")

      get categories_path(search_term: "  cristian pens ")

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.at_css("#show_category_#{category.id}")).to be_present
    end

    it "renders category links with the complete resolved pair" do
      category = create(:category, user:, category_name: "Dark category", colour: "#4b5563")

      get categories_path

      document = response.parsed_body
      badge = document.at_css("#show_category_#{category.id}")

      expect(badge["style"]).to include("background-color: #4b5563", "color: #ffffff")
      expect(badge["class"]).not_to include("hover:opacity")
    end

    it "renders categories grouped hierarchically with compound badges and subcategory action buttons" do
      parent = create(:category, :random, user:, category_name: "HSH", colour: "#112233", card_transactions_count: 2, card_transactions_total: 10_000)
      child = create(:category, :random, user:, category_name: "LABOUR", colour: "#445566", parent_category: parent, card_transactions_count: 3,
                                         card_transactions_total: 15_000)

      get categories_path

      expect(response).to have_http_status(:success)
      document = response.parsed_body

      parent_badge = document.at_css("#show_category_#{parent.id}")
      expect(parent_badge).to be_present
      expect(parent_badge.text).to eq("HSH")

      add_sub_button = document.at_css("#add_subcategory_#{parent.id}")
      expect(add_sub_button).to be_present
      expect(add_sub_button["href"]).to eq(new_category_path(parent_category_id: parent.id))

      parent_row = document.at_css("[data-id='#{parent.id}']")
      expect(parent_row.at_css(".jump_to_card_transactions").text.strip).to eq("5")
      expect(parent_row.text).to include("250.00")

      child_badge = document.at_css("#show_category_#{child.id}")
      expect(child_badge).to be_present
      expect(child_badge.text).to include("HSH")
      expect(child_badge.text).to include("LABOUR")
      expect(child_badge.at_css("[data-category-child-badge='true']")).to be_present

      expect(document.at_css("#add_subcategory_#{child.id}")).to be_nil
    end
  end

  describe "[ #show ]" do
    it "renders category details with a restorable lazy trend and context-scoped report data" do
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
      report_params = {
        from_date: "2026-04-01",
        to_date: "2026-04-30",
        granularity: "day",
        paid_state: "all",
        direction: "outcome"
      }
      get category_path(category), params: report_params

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Details")
      expect(response.body).to include(Entity.model_name.human(count: 2))
      expect(response.body).to include("User Bank Accounts")
      expect(response.body).to include("User Cards")

      trend = response.parsed_body.at_css("[data-controller~='allocation-trend']")
      expect(trend).to be_present
      expect(trend["data-allocation-trend-url-value"]).to eq(category_trend_path(category))
      expect(trend.at_css("#category_#{category.id}_trend_from_date")["value"]).to eq("2026-04-01")
      expect(trend.at_css("#category_#{category.id}_trend_to_date")["value"]).to eq("2026-04-30")
      expect(trend.at_css("#category_#{category.id}_trend_granularity option[selected]")["value"]).to eq("day")
      expect(trend.at_css("#category_#{category.id}_trend_direction option[selected]")["value"]).to eq("outcome")
      counterpart_payload = pie_payloads(response.body).fetch("counterpart")
      expect(counterpart_payload.fetch("filterOptions").pluck("label")).to include("Bank Account: 99PAY", "User Card: 99PAY")
      expect(counterpart_payload.fetch("entries").pluck("name")).to include("Scenario Entity")
      expect(counterpart_payload.to_json).not_to include("Main Entity")

      get category_trend_path(category), params: report_params

      payload = response.parsed_body
      expect(payload.dig("summary", "net_cents")).to eq(-8_000)
      expect(payload.fetch("breakdowns").pluck("label")).to all(include("Scenario Entity"))
      expect(payload.to_json).not_to include("Main Entity")
    end

    it "sums transactions with duplicate prices independently" do
      category = create(:category, user:, category_name: "DUPLICATE PRICES")
      user_card = user.user_cards.find_by!(user_card_name: "99PAY")
      cash_transactions = create_list(:cash_transaction, 2, user:, context: user.main_context, user_bank_account:, price: -2_000)
      card_transactions = create_list(:card_transaction, 2, user:, context: user.main_context, user_card:, price: -3_000)
      cash_transactions.each { |transaction| create(:category_transaction, transactable: transaction, category:) }
      card_transactions.each { |transaction| create(:category_transaction, transactable: transaction, category:) }

      get category_path(category)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("R$ -40.00", "R$ -60.00")
    end
  end

  describe "[ #trend ]" do
    it "returns a context-scoped category trend payload" do
      category = create(:category, user:, category_name: "REPORT FOOD")
      transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account:, date: Date.new(2026, 7, 10), month: 7, year: 2026,
                                              price: -1_500)
      create(:category_transaction, transactable: transaction, category:)

      get category_trend_path(category), params: { from_date: "2026-07-01", to_date: "2026-07-31" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to include(
        "resource" => { "type" => "Category", "id" => category.id, "label" => "REPORT FOOD" },
        "summary" => include("net_cents" => -1_500)
      )
    end

    it "rejects invalid report state and categories owned by another user" do
      category = create(:category, user:)
      foreign_category = create(:category, user: create(:user, :random))

      get category_trend_path(category), params: { from_date: "2026-09-01", to_date: "2026-01-01" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("code" => "invalid_range")

      get category_trend_path(foreign_category)
      expect(response).to have_http_status(:not_found)
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

    it "renders the parent category selector with eligible top-level categories" do
      parent = create(:category, :random, user:, category_name: "HSH")
      child = create(:category, :random, user:, category_name: "LABOUR", parent_category: parent)

      get new_category_path

      document = response.parsed_body
      selector = document.at_css("#category_parent_category_id")

      expect(selector).to be_present
      options = selector.css("option").map(&:text)
      expect(options).to include(parent.name)
      expect(options).not_to include(child.name)
    end

    it "pre-selects parent category when parent_category_id param is provided" do
      parent = create(:category, :random, user:, category_name: "HSH")

      get new_category_path(parent_category_id: parent.id)

      document = response.parsed_body
      selected_option = document.at_css("#category_parent_category_id option[selected]")

      expect(selected_option).to be_present
      expect(selected_option["value"]).to eq(parent.id.to_s)
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

    it "disables the parent selector and renders an informative note when category has subcategories" do
      parent = create(:category, :random, user:, category_name: "HSH")
      create(:category, :random, user:, category_name: "LABOUR", parent_category: parent)

      get edit_category_path(parent)

      document = response.parsed_body
      selector = document.at_css("#category_parent_category_id[disabled]")

      expect(selector).to be_present
      expect(response.body).to include(I18n.t("categories.form.has_subcategories_hint"))
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

    it "creates a subcategory assigned to a parent category" do
      parent = create(:category, :random, user:, category_name: "HSH")

      expect do
        post categories_path, params: {
          category: {
            category_name: "Labour",
            colour: "#123456",
            text_colour_mode: "automatic",
            active: true,
            user_id: user.id,
            parent_category_id: parent.id
          }
        }, headers: turbo_stream_headers
      end.to change(Category, :count).by(1)

      child = user.categories.find_by!(category_name: "Labour")
      expect(child.parent_category).to eq(parent)
      expect(child.parent_category_id).to eq(parent.id)
    end

    it "allows subcategories with the same name under different parents" do
      parent1 = create(:category, :random, user:, category_name: "HSH")
      parent2 = create(:category, :random, user:, category_name: "Assets")
      create(:category, :random, user:, category_name: "Supplies", parent_category: parent1)

      expect do
        post categories_path, params: {
          category: {
            category_name: "Supplies",
            colour: "#654321",
            text_colour_mode: "automatic",
            active: true,
            user_id: user.id,
            parent_category_id: parent2.id
          }
        }, headers: turbo_stream_headers
      end.to change(Category, :count).by(1)

      child2 = user.categories.find_by!(category_name: "Supplies", parent_category_id: parent2.id)
      expect(child2.parent_category).to eq(parent2)
    end

    it "rejects duplicate subcategory name under the same parent" do
      parent = create(:category, :random, user:, category_name: "HSH")
      create(:category, :random, user:, category_name: "Labour", parent_category: parent)

      expect do
        post categories_path, params: {
          category: {
            category_name: "Labour",
            colour: "#123456",
            text_colour_mode: "automatic",
            active: true,
            user_id: user.id,
            parent_category_id: parent.id
          }
        }, headers: turbo_stream_headers
      end.not_to change(Category, :count)

      expect(response).to have_http_status(:unprocessable_content)
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

    it "updates the parent category of a subcategory or clears it" do
      parent1 = create(:category, :random, user:, category_name: "HSH")
      parent2 = create(:category, :random, user:, category_name: "Assets")
      child = create(:category, :random, user:, category_name: "Tools", parent_category: parent1)

      patch category_path(child), params: {
        category: {
          category_name: child.category_name,
          colour: child.colour,
          text_colour_mode: "automatic",
          active: child.active,
          user_id: user.id,
          parent_category_id: parent2.id
        }
      }, headers: turbo_stream_headers

      expect(child.reload.parent_category).to eq(parent2)

      patch category_path(child), params: {
        category: {
          category_name: child.category_name,
          colour: child.colour,
          text_colour_mode: "automatic",
          active: child.active,
          user_id: user.id,
          parent_category_id: ""
        }
      }, headers: turbo_stream_headers

      expect(child.reload.parent_category).to be_nil
    end
  end

  describe "[ #destroy ]" do
    it "destroys a category without transactions" do
      category = create(:category, user:)

      expect do
        delete category_path(category), headers: turbo_stream_headers
      end.to change(Category, :count).by(-1)
    end

    it "prevents destroying a parent category that has subcategories" do
      parent = create(:category, :random, user:, category_name: "HSH")
      create(:category, :random, user:, category_name: "Labour", parent_category: parent)

      expect do
        delete category_path(parent), headers: turbo_stream_headers
      end.not_to change(Category, :count)

      expect(response).to redirect_to(categories_path)
      expect(flash[:alert]).to eq(I18n.t("notification.not_destroyed_because_has_subcategoriesa", model: Category.model_name.human))
    end
  end

  def pie_payloads(body)
    body.scan(/data-pie-breakdown-chart-data-value="([^"]+)"/).to_h do |(value)|
      payload = JSON.parse(CGI.unescapeHTML(value))
      [ payload.fetch("kind"), payload ]
    end
  end
end
    it "renders categories hierarchically and displays rollup totals for parent categories" do
      parent = create(:category, :random, user:, category_name: "HSH")
      child = create(:category, :random, user:, category_name: "LABOUR", parent_category: parent)
      user_card = create(:user_card, user:)
      create_list(:card_transaction, 5, user:, user_card:, category: child, price: 50.0)

      get categories_path

      document = response.parsed_body

      parent_badge = document.at_css("#show_category_#{parent.id}")
      expect(parent_badge).to be_present
      expect(parent_badge.text).to eq("HSH")

      add_sub_button = document.at_css("#add_subcategory_#{parent.id}")
      expect(add_sub_button).to be_present
      expect(add_sub_button["href"]).to eq(new_category_path(parent_category_id: parent.id))

      parent_row = document.at_css("[data-id='#{parent.id}']")
      expect(parent_row.at_css(".jump_to_card_transactions").text.strip).to eq("5")
      expect(parent_row.text).to include("250.00")

      child_badge = document.at_css("#show_category_#{child.id}")
      expect(child_badge).to be_present
      expect(child_badge.text).to include("HSH")
      expect(child_badge.text).to include("LABOUR")
