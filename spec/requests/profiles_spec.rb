# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /profile/edit" do
    it "returns http success" do
      pending "Not yet implemented"
      get "/profile/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /profile" do
    it "updates the profile and redirects" do
      pending "Not yet implemented"
      patch "/profile", params: { user_profile: { display_name: "New Name" } }
      expect(response).to redirect_to(edit_profile_path)
      expect(user.profile.reload.display_name).to eq("New Name")
    end
  end
end
