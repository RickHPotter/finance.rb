# frozen_string_literal: true

require "rails_helper"

RSpec.describe "External ledger HTTP security", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:owner) { create(:user, :random) }
  let(:entity) { create(:entity, user: owner) }
  let(:share) { Ledgers::Shares::Create.call(entity:, context: owner.main_context) }
  let(:rate_limit_store) { ActiveSupport::Cache::MemoryStore.new }

  before { allow(Rails).to receive(:cache).and_return(rate_limit_store) }

  it "applies privacy headers to redirects, full pages, fragments, and generic errors" do
    get external_root_path(share_token: share.token)
    expect_privacy_headers
    expect(request.filtered_path).to include("/shared/[FILTERED]")
    expect(request.filtered_path).not_to include(share.token)
    expect(response.filtered_location).to eq("[FILTERED]")

    get external_cash_transactions_path(share_token: share.token)
    expect_privacy_headers

    get month_year_external_cash_transactions_path(share_token: share.token),
        params: { month_year: 202_609 }, headers: { "Turbo-Frame" => "month_year_container_202609" }
    expect_privacy_headers

    get external_cash_transactions_path(share_token: "invalid-secret-token")
    expect_privacy_headers
    expect(response.body).not_to include("invalid-secret-token")

    get "/old-owner/external/old-entity/cash_transactions", params: { share_token: "invalid-legacy-secret" }
    expect_privacy_headers
    expect(response.body).not_to include("invalid-legacy-secret")
  end

  it "throttles invalid-token enumeration with the same generic unavailable surface" do
    stub_const("Ledgers::ExternalRateLimiter::NETWORK_LIMIT", 2)
    stub_const("Ledgers::ExternalRateLimiter::IDENTITY_LIMIT", 10)

    get external_cash_transactions_path(share_token: "invalid-one")
    generic_body = response.body
    expect(response).to have_http_status(:not_found)

    get external_cash_transactions_path(share_token: "invalid-two")
    expect(response).to have_http_status(:not_found)

    get external_cash_transactions_path(share_token: "invalid-three")
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to eq(generic_body)
    expect(response.headers["Retry-After"]).to eq("60")
    expect_privacy_headers
  end

  it "throttles repeated valid-share reads without affecting internal ledgers" do
    stub_const("Ledgers::ExternalRateLimiter::NETWORK_LIMIT", 10)
    stub_const("Ledgers::ExternalRateLimiter::IDENTITY_LIMIT", 2)

    2.times do
      get external_cash_transactions_path(share_token: share.token)
      expect(response).to have_http_status(:ok)
    end
    get external_cash_transactions_path(share_token: share.token)
    expect(response).to have_http_status(:too_many_requests)

    sign_in owner
    get internal_cash_transactions_path(entity_public_id: entity.public_id)
    expect(response).to have_http_status(:ok)
  end

  it "records telemetry only after authorization and keeps repeated fragment reads bounded" do
    travel_to Time.zone.local(2026, 9, 12, 12) do
      get external_cash_transactions_path(share_token: "invalid-token")
      expect(response).to have_http_status(:not_found)
      expect(share.share.reload).to have_attributes(access_count: 0, last_accessed_at: nil)

      get external_cash_transactions_path(share_token: share.token)
      expect(response).to have_http_status(:ok)
      expect(share.share.reload).to have_attributes(access_count: 1, last_accessed_at: Time.current)

      get month_year_external_cash_transactions_path(share_token: share.token), params: { month_year: 202_609 },
                                                                                headers: { "Turbo-Frame" => "month_year_container_202609" }
      expect(response).to have_http_status(:ok)
      expect(share.share.reload.access_count).to eq(1)
    end
  end

  private

  def expect_privacy_headers
    expect(response.headers).to include(
      "X-Robots-Tag" => "noindex, nofollow, noarchive",
      "Cache-Control" => "private, no-store",
      "Referrer-Policy" => "no-referrer"
    )
  end
end
