# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Balances", type: :request do
  let(:user) { create(:user, :random) }
  let(:account) { create(:user_bank_account, :random, user:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders the mobile-first balances route" do
      get balances_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("balances.title"))
      expect(response.body).to include("Legacy")
      expect(response.body).to include("Trend")
      expect(response.body).to include(I18n.t("balances.mobile.history"))
      expect(response.body).to include(I18n.t("balances.monthly_analysis.title"))
      expect(response.body).not_to include("data-balances-mobile-breakdown-url-value")
      expect(response.body).not_to include("data-balances-mobile-target=\"breakdownCanvas\"")

      document = Nokogiri::HTML.fragment(response.body)
      analysis_frame = document.at_css("turbo-frame#balances_monthly_analysis_content")
      expect(analysis_frame["src"]).to be_nil
      expect(analysis_frame["data-naming-tabs-lazy-src"]).to eq(monthly_analysis_balances_path)
      expect(response.body).not_to include("data-controller=\"balances-monthly-analysis\"")
    end
  end

  describe "[ #monthly_analysis ]" do
    it "renders the lazy monthly-analysis frame" do
      get monthly_analysis_balances_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame id="balances_monthly_analysis_content"')
      expect(response.body).to include(I18n.t("balances.monthly_analysis.title"))
      expect(response.body).to include(I18n.t("balances.monthly_analysis.subtitle"))

      document = Nokogiri::HTML.fragment(response.body)
      analysis = document.at_css('[data-controller="balances-monthly-analysis"]')
      expect(analysis["data-balances-monthly-analysis-url-value"]).to eq(monthly_analysis_json_balances_path(format: :json))
      expect(analysis["data-balances-monthly-analysis-locale-value"]).to eq("en")
      expect(analysis["data-balances-monthly-analysis-currency-value"]).to eq("BRL")
      expect(JSON.parse(analysis["data-balances-monthly-analysis-labels-value"])).to include("retry" => "Retry")
      expect(document.css("canvas[data-balances-monthly-analysis-target$='Canvas']").size).to eq(4)
      expect(response.body).not_to include("apexcharts")
    end

    it "renders Portuguese configuration from the signed-in user" do
      user.update!(locale: "pt-BR")

      get monthly_analysis_balances_path

      document = Nokogiri::HTML.fragment(response.body)
      analysis = document.at_css('[data-controller="balances-monthly-analysis"]')
      expect(response).to have_http_status(:ok)
      expect(analysis["data-balances-monthly-analysis-locale-value"]).to eq("pt-BR")
      expect(response.body).to include(I18n.t("balances.monthly_analysis.title", locale: "pt-BR"))
      expect(JSON.parse(analysis["data-balances-monthly-analysis-labels-value"])).to include("retry" => "Tentar novamente")
    end
  end

  describe "[ #monthly_analysis_json ]" do
    it "returns the selected month payload" do
      expect(monthly_analysis_json_balances_path(format: :json)).to eq("/balances/monthly_analysis.json")

      get monthly_analysis_json_balances_path(format: :json), params: { month: "2026-07" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "month" => "2026-07",
        "ordinary" => {
          "income" => { "total" => 0.0, "categories" => [], "entities" => [] },
          "outcome" => { "total" => 0.0, "categories" => [], "entities" => [] },
          "net" => 0.0
        }
      )
    end

    it "returns a localized unprocessable response for invalid month input" do
      get monthly_analysis_json_balances_path(format: :json), params: { month: "2026-13" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => I18n.t("balances.monthly_analysis.invalid_month"))
    end

    it "rejects a missing month without running a fallback query" do
      get monthly_analysis_json_balances_path(format: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => I18n.t("balances.monthly_analysis.invalid_month"))
    end

    it "uses the active financial context" do
      derived_context = create(:context, user:)
      create_context_cash_transaction(user.main_context, price: 1_000)
      create_context_cash_transaction(derived_context, price: 2_000)
      patch switch_context_path(derived_context)

      get monthly_analysis_json_balances_path(format: :json), params: { month: "2026-07" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("ordinary", "income", "total")).to eq(20.0)
    end
  end

  describe "[ #legacy ]" do
    it "renders the legacy balances route" do
      get legacy_balances_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("balances.title"))
    end
  end

  def create_context_cash_transaction(context, price:)
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid: false) ],
      category_transactions: [],
      entity_transactions: []
    )
  end
end
