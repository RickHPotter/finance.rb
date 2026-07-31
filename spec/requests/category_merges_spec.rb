# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category merges" do
  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /categories/:id/merge" do
    let(:plan) { CategoryMerges::Planner.new(actor: user, source_id: source.id, destination_id: destination.id).call }
    let(:token) { CategoryMerges::PreviewToken.generate(plan) }
    let(:merge_params) { { merge_token: token, return_to: "/custom" } }

    it "applies the merge and redirects for Turbo Stream requests" do
      post merge_category_path(source), params: merge_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to redirect_to("/custom")
      expect(flash[:notice]).to eq(I18n.t("category_merges.applied"))
      expect(Category.exists?(source.id)).to be(false)
    end

    it "applies the merge and redirects via HTML" do
      post merge_category_path(source), params: merge_params

      expect(response).to redirect_to("/custom")
      expect(flash[:notice]).to eq(I18n.t("category_merges.applied"))
      expect(Category.exists?(source.id)).to be(false)
    end

    it "returns unprocessable_content on rejection and streams notification only" do
      post merge_category_path(source), params: { merge_token: "invalid_token_string", return_to: "/custom" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")

      # Should NOT redirect
      expect(response.body).not_to include('action="redirect"')

      # Should include flash alert
      expect(response.body).to include('turbo-stream action="update" target="notification"')
      expect(response.body).to include(I18n.t("category_merges.reasons.invalid_token"))

      expect(Category.exists?(source.id)).to be(true)
    end

    it "returns 404 if source category belongs to another user" do
      other_user = create(:user, :random)
      other_source = create(:category, user: other_user)

      post merge_category_path(other_source), params: merge_params
      expect(response).to have_http_status(:not_found)
    end
  end
end
