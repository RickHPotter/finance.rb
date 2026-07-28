# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check repair apply", type: :request do
  let(:admin) { create(:user, :random, admin: true) }
  let(:operation) do
    AuditOperation.create!(
      source: :admin_repair,
      result: :committed,
      actor_id: admin.id,
      context_id: admin.main_context.id,
      metadata: {
        health_check_key: "exchange_trio",
        repair_key: "canonical_reference",
        finding_key: "41",
        preview_digest: "a" * 64
      }
    )
  end

  it "requires authentication and hides apply from ordinary users" do
    patch apply_path
    expect(response).to redirect_to(new_user_session_path)

    sign_in create(:user, :random)
    patch apply_path
    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for unknown and diagnostic-only repairs" do
    sign_in admin

    patch healthcheck_repair_path("exchange_trio", "unknown")
    expect(response).to have_http_status(:not_found)

    patch healthcheck_repair_path("piggy_bank", "projection")
    expect(response).to have_http_status(:not_found)
  end

  it "cannot bypass preview and confirmation with a direct apply request" do
    sign_in admin

    expect do
      patch apply_path
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("health_check.repairs.result.reasons.invalid_token"))
    expect(response.body).not_to include("/audit_operations/")
  end

  it "passes the validated scope, signed token, and explicit confirmation to apply" do
    result = HealthCheck::Repairs::ApplyResult.new(
      status: "applied",
      operation_id: operation.id,
      changed_count: 3,
      rerun_reason: "queued"
    )
    service = instance_double(HealthCheck::Repairs::Apply, call: result)
    expect(HealthCheck::Repairs::Apply).to receive(:new) do |definition:, scope:, request_id:, token:, confirmed:|
      expect(definition).to eq(HealthCheck::Repairs::Registry.fetch("exchange_trio", "canonical_reference"))
      expect(scope.to_h).to include(user_id: admin.id, context_id: admin.main_context.id)
      expect(request_id).to be_present
      expect(token).to eq("signed-token")
      expect(confirmed).to eq("1")
      service
    end
    sign_in admin

    patch apply_path, params: { apply_token: "signed-token", repair_confirmation: "1" }

    document = Nokogiri::HTML(response.body)
    stream_source = document.at_css("turbo-cable-stream-source")
    expect(response).to have_http_status(:success)
    expect(document.at_css("#health_check_repair_result")).to be_present
    expect(document.at_css("#health_check_check_exchange_trio")).to be_present
    expect(Turbo::StreamsChannel.verified_stream_name(stream_source["signed-stream-name"])).to eq(
      HealthCheck::Stream.name(user_id: admin.id, context_id: admin.main_context.id, connected_user_id: nil)
    )
    expect(response.body).to include(operation.id)
    expect(document.css("a").map { |node| node["href"] }).to include(audit_operation_path(operation))
  end

  it "renders stale and invalid apply attempts without a success notice or audit link" do
    result = HealthCheck::Repairs::ApplyResult.new(status: "rejected", reason_code: "stale_preview")
    allow(HealthCheck::Repairs::Apply).to receive(:new).and_return(instance_double(HealthCheck::Repairs::Apply, call: result))
    sign_in admin

    patch apply_path, params: { apply_token: "stale", repair_confirmation: "1" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("health_check.repairs.result.reasons.stale_preview"))
    expect(response.body).not_to include(I18n.t("health_check.repairs.result.states.applied.title"))
    expect(response.body).not_to include("/audit_operations/")
  end

  def apply_path
    healthcheck_repair_path("exchange_trio", "canonical_reference")
  end
end
