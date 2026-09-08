# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity merges" do
  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:source) { create(:entity, :random, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, :random, user:, entity_name: "DESTINATION") }

  before { sign_in user }

  describe "POST /entities/:id/merge" do
    let(:plan) { EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call }
    let(:token) { EntityMerges::PreviewToken.generate(plan) }
    let(:return_to) do
      Navigation::Entities.new(
        raw: entities_path(search_term: "shop", entity: { status: [ "active" ] }),
        fallback: entities_path,
        current_user: user
      ).destination
    end
    let(:merge_params) { { merge_token: token, mode: "strict", return_to: } }

    it "applies the merge and redirects for Turbo Stream requests" do
      post merge_entity_path(source), params: merge_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to redirect_to(return_to)
      expect(flash[:notice]).to eq(I18n.t("entity_merges.applied", default: "Entity merged successfully"))
      expect(Entity.exists?(source.id)).to be(false)
    end

    it "applies the merge and redirects via HTML" do
      post merge_entity_path(source), params: merge_params

      expect(response).to redirect_to(return_to)
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

    it "rejects an apply request without the previewed mode" do
      post merge_entity_path(source), params: merge_params.except(:mode), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("entity_merges.reasons.invalid_mode"))
      expect(Entity.exists?(source.id)).to be(true)
    end

    it "returns 404 if source entity belongs to another user" do
      other_user = create(:user, :random)
      other_source = create(:entity, :random, user: other_user)

      post merge_entity_path(other_source), params: merge_params
      expect(response).to have_http_status(:not_found)
    end

    it "rejects an unsafe return path in favor of the canonical entity index" do
      post merge_entity_path(source), params: merge_params.merge(return_to: "https://example.test/escape")

      expect(response).to redirect_to(entities_path)
    end

    it "applies a previewed eligible-only subset and retains the conflicted source" do
      bank_account = create(:user_bank_account, :random, user:, bank: create(:bank, :random))
      neutral_transaction = create(:cash_transaction, user:, context:, user_bank_account: bank_account, price: 0)
      conflict_transaction = create(:cash_transaction, user:, context:, user_bank_account: bank_account, price: 0)
      neutral_row = neutral_transaction.entity_transactions.create!(entity: source, price: 0, is_payer: false)
      conflict_row = conflict_transaction.entity_transactions.create!(entity: source, price: 100, is_payer: false)
      eligible_plan = EntityMerges::Planner.new(
        actor: user,
        context:,
        source_id: source.id,
        destination_id: destination.id,
        mode: :eligible_only
      ).call

      post merge_entity_path(source), params: {
        merge_token: EntityMerges::PreviewToken.generate(eligible_plan),
        mode: "eligible_only",
        return_to:
      }

      expect(response).to redirect_to(return_to)
      expect(source.reload).to be_persisted
      expect(neutral_row.reload.entity).to eq(destination)
      expect(conflict_row.reload.entity).to eq(source)
    end
  end
end
