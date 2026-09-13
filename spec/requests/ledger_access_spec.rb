# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity ledger access boundaries", type: :request do
  let(:owner) { create(:user, :random) }
  let(:entity) { create(:entity, user: owner, entity_name: "PRIVATE LEDGER ENTITY") }

  describe "internal endpoints" do
    it "requires authentication before every root, index, search, and month request" do
      internal_paths(entity.public_id).each do |path, params|
        get path, params: params

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "rejects every direct endpoint request for another owner's Entity" do
      foreign_entity_public_id = entity.public_id
      intruder = create(:user, :random)

      internal_paths(foreign_entity_public_id).each do |path, params|
        sign_in intruder
        get path, params: params

        expect(response).to have_http_status(:not_found)
      end
    end

    it "authorizes every endpoint through the signed-in owner and active Context" do
      sign_in owner

      internal_paths(entity.public_id).each do |path, params|
        get path, params: params

        expect(response).to have_http_status(:ok).or have_http_status(:moved_permanently)
      end
    end
  end

  describe "external endpoints" do
    it "requires the active share on every root, index, search, and month request" do
      active = Ledgers::Shares::Create.call(entity:, context: owner.main_context)

      external_paths(active.token).each do |path, params|
        get path, params: params

        expect(response).to have_http_status(:ok).or have_http_status(:moved_permanently)
      end
    end

    it "returns the same unavailable response for unknown, expired, and revoked shares on every endpoint" do
      expired = Ledgers::Shares::Create.call(entity:, context: owner.main_context, expires_at: 1.day.from_now)
      expired.share.update_column(:expires_at, 1.minute.ago)
      revoked = Ledgers::Shares::Create.call(entity:, context: owner.main_context)
      Ledgers::Shares::Revoke.call(share: revoked.share)

      [ "unknown-token", expired.token, revoked.token ].each do |token|
        external_paths(token).each do |path, params|
          get path, params: params

          expect(response).to have_http_status(:not_found)
          expect(response.body).to include("Ledger unavailable")
          expect(response.body).not_to include(owner.first_name, entity.entity_name)
        end
      end
    end

    it "ignores conflicting owner, Entity, and Context parameters" do
      active = Ledgers::Shares::Create.call(entity:, context: owner.main_context)
      foreign_user = create(:user, :random)
      foreign_entity = create(:entity, user: foreign_user)

      get external_cash_transactions_path(share_token: active.token), params: {
        user_id: foreign_user.id,
        user_slug: foreign_user.first_name.parameterize,
        entity_public_id: foreign_entity.public_id,
        entity_slug: foreign_entity.entity_name.parameterize,
        context_id: foreign_user.main_context.id,
        cash_transaction: { entity_id: [ foreign_entity.id ] }
      }

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css("form#search_form")["action"]).to eq(external_cash_transactions_path(share_token: active.token))
    end

    it "does not authorize the obsolete owner-and-Entity slug URL" do
      get "/#{owner.first_name.parameterize}/external/#{entity.entity_name.parameterize}"
      expect(response).to have_http_status(:not_found)
    end

    it "keeps every endpoint of the explicit lalas alias public" do
      create(:entity, user: owner, entity_name: "LALA")

      lalas_paths.each do |path, params|
        get path, params: params

        expect(response).to have_http_status(:ok).or have_http_status(:moved_permanently)
        expect(response.headers).to include(
          "X-Robots-Tag" => "noindex, nofollow, noarchive",
          "Cache-Control" => "private, no-store",
          "Referrer-Policy" => "no-referrer"
        )
      end
    end

    it "fails closed when the public lalas identity is missing or ambiguous" do
      get lalas_root_path
      expect(response).to have_http_status(:not_found)

      create(:entity, user: owner, entity_name: "LALA")
      other_owner = create(:user, :random)
      create(:entity, user: other_owner, entity_name: "lala")

      get lalas_root_path
      expect(response).to have_http_status(:not_found)
    end
  end

  private

  def internal_paths(entity_public_id)
    [
      [ internal_root_path(entity_public_id:), {} ],
      [ internal_cash_transactions_path(entity_public_id:), {} ],
      [ search_internal_cash_transactions_path(entity_public_id:), {} ],
      [ month_year_internal_cash_transactions_path(entity_public_id:), { month_year: "202609" } ],
      [ internal_card_transactions_path(entity_public_id:), {} ],
      [ search_internal_card_transactions_path(entity_public_id:), {} ],
      [ month_year_internal_card_transactions_path(entity_public_id:), { month_year: "202609" } ]
    ]
  end

  def external_paths(share_token)
    [
      [ external_root_path(share_token:), {} ],
      [ external_cash_transactions_path(share_token:), {} ],
      [ search_external_cash_transactions_path(share_token:), {} ],
      [ month_year_external_cash_transactions_path(share_token:), { month_year: "202609" } ],
      [ external_card_transactions_path(share_token:), {} ],
      [ search_external_card_transactions_path(share_token:), {} ],
      [ month_year_external_card_transactions_path(share_token:), { month_year: "202609" } ]
    ]
  end

  def lalas_paths
    [
      [ lalas_root_path, {} ],
      [ lalas_cash_transactions_path, {} ],
      [ search_lalas_cash_transactions_path, {} ],
      [ month_year_lalas_cash_transactions_path, { month_year: "202609" } ],
      [ lalas_card_transactions_path, {} ],
      [ search_lalas_card_transactions_path, {} ],
      [ month_year_lalas_card_transactions_path, { month_year: "202609" } ]
    ]
  end
end
