# frozen_string_literal: true

require "rails_helper"

RSpec.describe "NamingConventions", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #preview ]" do
    it "renders successfully" do
      post preview_naming_convention_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #update ]" do
    it "renders successfully as turbo stream" do
      patch naming_convention_path, headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
    end
  end
end
