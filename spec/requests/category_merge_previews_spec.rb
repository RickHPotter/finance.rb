# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category merge previews" do
  let(:user) { create(:user) }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /categories/:id/merge_preview" do
    let(:return_to) do
      Navigation::Categories.new(
        raw: categories_path(search_term: "source", category: { status: [ "active" ] }),
        fallback: categories_path,
        current_user: user
      ).destination
    end
    let(:preview_params) { { category_merge: { destination_id: destination.id, return_to: } } }

    it "opens a destination chooser without manufacturing a missing-destination conflict" do
      post merge_preview_category_path(source), params: { category_merge: { return_to: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      document = Nokogiri::HTML.parse(response.body)
      frame = document.at_css("#category_merge_preview_#{source.id}")

      expect(response).to have_http_status(:ok)
      expect(frame.at_css("#category_merge_destination_id_#{source.id}")).to be_present
      expect(frame.text).not_to include(I18n.t("category_merges.preview.outcome.conflict"))
      expect(frame.at_css(%[a[href="#{return_to}"]])).to be_present
    end

    it "renders the preview frame via Turbo Stream" do
      post merge_preview_category_path(source), params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("category_merge_preview_#{source.id}")
      expect(response.body).to include(destination.category_name)
      expect(response.body).to include("Ready to apply")
    end

    it "renders the preview page via HTML" do
      post merge_preview_category_path(source), params: preview_params

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("category_merge_preview_#{source.id}")
    end

    it "renders the plan payload via JSON" do
      post merge_preview_category_path(source), params: preview_params, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      json = response.parsed_body
      expect(json["outcome"]).to eq("eligible")
      expect(json["transaction_reassign_count"]).to eq(0)
    end

    it "returns 404 if the source category belongs to another user" do
      other_user = create(:user, :random)
      other_source = create(:category, user: other_user)

      post merge_preview_category_path(other_source), params: preview_params
      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 if category_merge param is missing" do
      post merge_preview_category_path(source)
      expect(response).to have_http_status(:bad_request)
    end

    it "excludes inactive and protected destinations and reports a forged protected source" do
      inactive = create(:category, :random, user:, active: false, built_in: false)
      protected_category = user.categories.find_by!(built_in: true)
      destination

      post merge_preview_category_path(source), params: { category_merge: { return_to: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      document = Nokogiri::HTML.parse(response.body)
      option_values = document.css("option").map { |option| option["value"] }

      expect(option_values).to include(destination.id.to_s)
      expect(option_values).not_to include(source.id.to_s, inactive.id.to_s, protected_category.id.to_s)

      post merge_preview_category_path(protected_category), params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include(I18n.t("category_merges.reasons.source_protected"))
    end
  end
end
