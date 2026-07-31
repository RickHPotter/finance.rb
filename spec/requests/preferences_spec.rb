# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Preferences", type: :request do
  describe "GET /update" do
    it "returns http success" do
      get "/preferences/update"
      expect(response).to have_http_status(:success)
    end
  end
end
