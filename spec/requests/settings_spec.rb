# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings compatibility redirect", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "temporarily redirects ordinary users to the canonical Health Check route" do
    get settings_path

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to(healthcheck_path)
  end

  it "temporarily redirects administrators without rendering a legacy Settings surface" do
    user.update!(admin: true)

    get settings_path

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to(healthcheck_path)
    expect(response.body).not_to include("settings_")
  end
end
