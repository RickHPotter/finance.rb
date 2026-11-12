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

    it "saves the selected sex and shows it when reopening the profile" do
      patch profile_path, params: { user_profile: { sex: "masculine" } }

      expect(response).to redirect_to(edit_profile_path)
      expect(user.profile.reload.sex).to eq("masculine")

      get edit_profile_path
      expect(response.parsed_body.at_css("select[name='user_profile[sex]'] option[selected]")["value"]).to eq("masculine")
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
