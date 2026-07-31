# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Preferences", type: :request do
  let(:user) { create(:user) }

  before do
    login_as(user)
  end

  describe "PATCH /preference" do
    it "returns http redirect on success" do
      patch "/preference", params: { user_preference: { theme: "light" } }
      expect(response).to have_http_status(:redirect)
    end
  end
end
