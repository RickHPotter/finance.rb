# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity merge previews" do
  let(:user) { create(:user) }
  let(:source) { create(:entity, :random, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, :random, user:, entity_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /entities/:id/merge_preview" do
    let(:return_to) do
      Navigation::Entities.new(
        raw: entities_path(search_term: "source", entity: { status: [ "active" ] }),
        fallback: entities_path,
        current_user: user
      ).destination
    end
    let(:preview_params) { { entity_merge: { destination_id: destination.id, return_to:, mode: "strict" } } }

    it "opens a destination chooser without manufacturing a missing-destination conflict" do
      post merge_preview_entity_path(source), params: { entity_merge: { return_to:, mode: "strict" } },
                                              headers: { "Accept" => "text/vnd.turbo-stream.html" }

      document = Nokogiri::HTML.parse(response.body)
      frame = document.at_css("#entity_merge_preview_#{source.id}")

      expect(response).to have_http_status(:ok)
      expect(frame.at_css("#entity_merge_destination_id_#{source.id}")).to be_present
      expect(frame.text).not_to include(I18n.t("entity_merges.preview.outcome.conflict"))
      expect(frame.at_css(%[a[href="#{return_to}"]])).to be_present
    end

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

    it "offers only destinations compatible with the source friend identity" do
      friend = create(:user, :random)
      other_friend = create(:user, :random)
      source.update!(entity_user: friend)
      destination.update!(entity_user: friend)
      ordinary = create(:entity, :random, user:, entity_user: nil)
      other_friend_entity = create(:entity, :random, user:, entity_user: other_friend)

      post merge_preview_entity_path(source), params: { entity_merge: { return_to:, mode: "strict" } },
                                              headers: { "Accept" => "text/vnd.turbo-stream.html" }
      option_values = Nokogiri::HTML.parse(response.body).css("option").map { |option| option["value"] }

      expect(option_values).to include(destination.id.to_s)
      expect(option_values).not_to include(source.id.to_s, ordinary.id.to_s, other_friend_entity.id.to_s, user.built_in_entity.id.to_s)

      post merge_preview_entity_path(user.built_in_entity), params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include(I18n.t("entity_merges.reasons.source_protected"))
    end

    it "surfaces strict conflicts and re-previews an independent eligible-only transfer before apply" do
      bank_account = create(:user_bank_account, :random, user:, bank: create(:bank, :random))
      neutral_transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account: bank_account, price: 0)
      conflict_transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account: bank_account, price: 0)
      neutral_transaction.entity_transactions.create!(entity: source, price: 0, is_payer: false)
      conflict_transaction.entity_transactions.create!(entity: source, price: 100, is_payer: false)

      post merge_preview_entity_path(source), params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(I18n.t("entity_merges.reasons.monetary_entity"))
      expect(response.body).to include(I18n.t("entity_merges.preview.submit_apply_eligible"))
      expect(response.body).not_to include(%[id="apply_entity_merge_#{source.id}"])

      post merge_preview_entity_path(source), params: preview_params.deep_merge(entity_merge: { mode: "eligible_only" }),
                                              headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%[id="apply_entity_merge_eligible_#{source.id}"])
      expect(response.body).to include(%[value="eligible_only"])
    end
  end
end
