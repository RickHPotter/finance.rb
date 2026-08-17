# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /profile/edit" do
    it "returns http success" do
      get "/profile/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /profile" do
    it "updates the profile and redirects" do
      patch "/profile", params: { user_profile: { first_name: "New", last_name: "Name" } }
      expect(response).to redirect_to(edit_profile_path)
      expect(user.profile.reload.display_name).to eq("New Name")
    end

    it "updates the user preference with new fields" do
      patch "/profile", params: {
        user_preference: {
          exchange_default_bound_type: "card_bound",
          row_color_mode: "row_coloured"
        }
      }
      expect(response).to redirect_to(edit_profile_path)
      preference = user.preference.reload
      expect(preference.exchange_default_bound_type).to eq("card_bound")
      expect(preference.row_color_mode).to eq("row_coloured")
    end
  end
end
