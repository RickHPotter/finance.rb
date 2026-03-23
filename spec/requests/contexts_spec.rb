# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contexts", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #switch ]" do
    it "stores the selected context in session" do
      scenario_context = create(:context, user:, name: "Scenario A")

      patch switch_context_path(scenario_context)

      expect(session[:current_context_id]).to eq(scenario_context.id)
      expect(response).to redirect_to(root_path)
    end

    it "does not allow switching to another user's context" do
      foreign_context = create(:context, user: create(:user, :random), name: "Foreign")

      patch switch_context_path(foreign_context)

      expect(response).to have_http_status(:not_found)
    end
  end
end
