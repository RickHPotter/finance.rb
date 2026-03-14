# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Static", type: :request do
  let(:user) { create(:user) }

  describe "[ GET / ]" do
    context "when not logged in" do
      it "redirects to sign-in" do
        get root_path

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      before { sign_in user }

      it "renders successfully" do
        get root_path

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "[ GET /static/donation ]" do
    before { sign_in user }

    it "renders successfully" do
      get donation_static_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ GET /static/notification ]" do
    before { sign_in user }

    it "renders successfully" do
      get notification_static_path, params: { notice: "Saved" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Saved")
    end
  end
end
