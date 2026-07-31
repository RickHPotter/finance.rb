# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity merges" do
  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:source) { create(:entity, :random, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, :random, user:, entity_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /entities/:id/merge" do
    let(:plan) { EntityMerges::Planner.new(actor: user, source_id: source.id, destination_id: destination.id).call }
    let(:token) { EntityMerges::PreviewToken.generate(plan) }
    let(:merge_params) { { merge_token: token, mode: "strict", return_to: "/custom" } }

    it "applies the merge and redirects for Turbo Stream requests" do
      post merge_entity_path(source), params: merge_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to redirect_to("/custom")
      expect(flash[:notice]).to eq(I18n.t("entity_merges.applied", default: "Entity merged successfully"))
      expect(Entity.exists?(source.id)).to be(false)
    end

    it "applies the merge and redirects via HTML" do
      post merge_entity_path(source), params: merge_params

      expect(response).to redirect_to("/custom")
      expect(flash[:notice]).to eq(I18n.t("entity_merges.applied", default: "Entity merged successfully"))
      expect(Entity.exists?(source.id)).to be(false)
    end

    it "returns unprocessable_content on rejection and streams notification only" do
      post merge_entity_path(source), params: { merge_token: "invalid_token_string", mode: "strict", return_to: "/custom" },
                                      headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")

      # Should NOT redirect
      expect(response.body).not_to include('action="redirect"')

      # Should include flash alert
      expect(response.body).to include('turbo-stream action="update" target="notification"')

      expect(Entity.exists?(source.id)).to be(true)
    end

    it "returns 404 if source entity belongs to another user" do
      other_user = create(:user, :random)
      other_source = create(:entity, :random, user: other_user)

      post merge_entity_path(other_source), params: merge_params
      expect(response).to have_http_status(:not_found)
    end
  end
end
