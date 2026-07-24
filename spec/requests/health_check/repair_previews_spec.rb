# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check repair previews", type: :request do
  let(:admin) { create(:user, :random, admin: true) }
  let(:change) do
    HealthCheck::Repairs::Change.new(
      record_type: "CashTransaction",
      record_id: 41,
      attribute: "reference_transactable",
      before: { type: "CashTransaction", id: 12 },
      after: { type: "CashTransaction", id: 13 }
    )
  end
  let(:result) do
    HealthCheck::Repairs::Result.new(
      finding_id: 41,
      state: "previewable",
      changes: [ change ],
      references: [ { type: "Message", id: 17 } ],
      paid_history: { affected: false }
    )
  end

  it "requires authentication and keeps the preview route undiscoverable to non-admins" do
    post preview_path
    expect(response).to redirect_to(new_user_session_path)

    sign_in create(:user, :random)
    post preview_path
    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for unknown repairs, Piggy Bank repairs, and foreign findings" do
    sign_in admin

    post healthcheck_repair_preview_path("exchange_trio", "unknown"), params: { finding_id: 41 }
    expect(response).to have_http_status(:not_found)

    post healthcheck_repair_preview_path("piggy_bank", "projection"), params: { finding_id: 41 }
    expect(response).to have_http_status(:not_found)

    planner = instance_double(HealthCheck::Repairs::CanonicalReferencePlanner)
    allow(HealthCheck::Repairs::CanonicalReferencePlanner).to receive(:new).and_return(planner)
    allow(planner).to receive(:call).and_raise(ActiveRecord::RecordNotFound)
    post preview_path
    expect(response).to have_http_status(:not_found)
  end

  it "renders a signed read-only preview in the selected scope without financial history or jobs" do
    planner = instance_double(HealthCheck::Repairs::CanonicalReferencePlanner, call: result)
    expect(HealthCheck::Repairs::CanonicalReferencePlanner).to receive(:new) do |scope:, finding_id:, options:|
      expect(scope.to_h).to include(user_id: admin.id, context_id: admin.main_context.id)
      expect(finding_id).to eq("41")
      expect(options.to_h).to eq({})
      planner
    end
    sign_in admin

    operation_count = AuditOperation.count
    version_count = AuditVersion.count
    job_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size
    post preview_path

    expect(AuditOperation.count).to eq(operation_count)
    expect(AuditVersion.count).to eq(version_count)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(job_count)

    document = Nokogiri::HTML(response.body)
    token = document.at_css("#health_check_repair_apply_token")["value"]
    apply_form = document.at_css("form[action='/healthcheck/checks/exchange_trio/repairs/canonical_reference']")

    expect(response).to have_http_status(:success)
    expect(document.at_css("#health_check_repair_preview_changes")).to be_present
    expect(apply_form).to be_present
    expect(apply_form.at_css("input[name='repair_confirmation']")).to be_present
    expect(apply_form.at_css("input[name='_method']")["value"]).to eq("patch")
    expect(document.at_css("#health_check_repair_preview_digest").text).to include(
      I18n.t("health_check.repairs.preview.digest")
    )
    expect(HealthCheck::Repairs::PreviewToken.verify(token)).to include(
      "actor_id" => admin.id,
      "context_id" => admin.main_context.id,
      "finding_id" => "41"
    )
  end

  it "preserves a validated connected-user scope through the planner and back link" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED", entity_user: connected_user)
    planner = instance_double(HealthCheck::Repairs::CanonicalReferencePlanner, call: result)
    expect(HealthCheck::Repairs::CanonicalReferencePlanner).to receive(:new) do |scope:, **|
      expect(scope.connected_user).to eq(connected_user)
      planner
    end
    sign_in admin

    post preview_path, params: { finding_id: 41, connected_user_id: connected_user.id }

    back_link = Nokogiri::HTML(response.body).css("a").find { |node| node.text.include?(I18n.t("health_check.repairs.preview.back")) }
    query = Rack::Utils.parse_nested_query(URI.parse(back_link["href"]).query)
    expect(query).to include("connected_user_id" => connected_user.id.to_s)
  end

  def preview_path
    healthcheck_repair_preview_path("exchange_trio", "canonical_reference", finding_id: 41)
  end
end
