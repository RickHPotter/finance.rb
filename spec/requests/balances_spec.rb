# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Balances", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders the mobile-first balances route" do
      get balances_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("balances.title"))
      expect(response.body).to include("Legacy")
      expect(response.body).to include("Trend")
      expect(response.body).to include("Breakdown")
    end
  end

  describe "[ #legacy ]" do
    it "renders the legacy balances route" do
      get legacy_balances_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("balances.title"))
    end
  end
end
