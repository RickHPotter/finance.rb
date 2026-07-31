# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity merge previews" do
  let(:user) { create(:user) }
  let(:source) { create(:entity, :random, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, :random, user:, entity_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /entities/:id/merge_preview" do
    let(:preview_params) { { entity_merge: { destination_id: destination.id, return_to: "/custom", mode: "strict" } } }

    it "renders the preview frame via Turbo Stream" do
      post merge_preview_entity_path(source), params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("entity_merge_preview_#{source.id}")
      expect(response.body).to include(destination.name)
    end

    it "renders the preview page via HTML" do
      post merge_preview_entity_path(source), params: preview_params

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("entity_merge_preview_#{source.id}")
    end

    it "renders the plan payload via JSON" do
      post merge_preview_entity_path(source), params: preview_params, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      json = response.parsed_body
      expect(json["outcome"]).to eq("eligible")
      expect(json["transaction_reassign_count"]).to eq(0)
    end

    it "returns 404 if the source entity belongs to another user" do
      other_user = create(:user, :random)
      other_source = create(:entity, :random, user: other_user)

      post merge_preview_entity_path(other_source), params: preview_params
      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 if entity_merge param is missing" do
      post merge_preview_entity_path(source)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
