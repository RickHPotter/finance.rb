# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages#Home", type: :request do
  let(:user) { create(:user) }

  describe "[ GET / ]" do
    context "( when not logged in )" do
      it "redirects to sign-in page on request to /" do
        get "/"

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "( when logged in )" do
      before { sign_in user }

      it "succeeds on request to /" do
        get "/"

        expect(response).to have_http_status(:success)
      end

      it "redirects to sign-in page on logout" do
        sign_out user
        get "/"

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # @TODO: Form Submission, Page Content, Flash Messages
end
