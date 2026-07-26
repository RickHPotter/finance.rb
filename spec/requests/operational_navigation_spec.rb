# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check and audit navigation", type: :request do
  let(:admin) { create(:user, :random, admin: true) }
  let(:operation) { create_audited_operation(item_id: 101) }

  before { sign_in admin }

  it "renders every operational GET as a canonical top-level HTML screen" do
    [
      healthcheck_path,
      healthcheck_check_path("piggy_bank"),
      audit_operations_path,
      audit_versions_path,
      audit_operation_path(operation),
      admin_audit_operation_rollback_preview_path(operation)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).to include(%[turbo-frame id="center_container"])
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format operational entry URLs" do
    {
      healthcheck_path(format: :turbo_stream) => healthcheck_path,
      healthcheck_check_path("piggy_bank", format: :turbo_stream) => healthcheck_check_path("piggy_bank"),
      audit_operations_path(format: :turbo_stream) => audit_operations_path,
      audit_versions_path(format: :turbo_stream) => audit_versions_path,
      audit_operation_path(operation, format: :turbo_stream) => audit_operation_path(operation)
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks audit filters, pagination, and detail links as top-level advances while retaining state" do
    operation
    create_audited_operation(item_id: 202)

    get audit_operations_path, params: { source: "web", per_page: 1 }

    document = Nokogiri::HTML(response.body)
    filter_form = document.at_css("form[action='#{audit_operations_path}'][method='get']")
    detail_link = document.at_css("a[href^='/audit_operations/']")
    next_link = document.css("nav a").find { |link| link.text.strip == I18n.t("navigation.next") }

    expect_top_level_advance(filter_form)
    expect_top_level_advance(detail_link)
    expect_top_level_advance(next_link)
    expect(Rack::Utils.parse_nested_query(URI.parse(next_link["href"]).query)).to include(
      "source" => "web",
      "per_page" => "1",
      "page" => "2"
    )
  end

  it "advances from an operation to its rollback preview" do
    get audit_operation_path(operation)

    document = Nokogiri::HTML(response.body)
    preview_link = document.at_css("a[href='#{admin_audit_operation_rollback_preview_path(operation)}']")

    expect_top_level_advance(preview_link)
  end

  it "returns a local detail rerun to the same canonical check and allowlisted filters" do
    destination = healthcheck_check_path(
      "piggy_bank",
      page: 2,
      per_page: 25,
      status_filter: "pending",
      issue_filter: "missing_projection"
    )

    post healthcheck_check_run_path("piggy_bank"), params: {
      return_to: "check",
      page: 2,
      per_page: 25,
      status_filter: "pending",
      issue_filter: "missing_projection",
      ignored: "secret"
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(destination)

    post healthcheck_check_run_path("piggy_bank"), params: { return_to: "https://evil.example/check" }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(healthcheck_path)
  end

  private

  def create_audited_operation(item_id:)
    audit_operation = AuditOperation.create!(
      source: :web,
      result: :committed,
      actor_id: admin.id,
      context_id: admin.main_context.id,
      request_id: "navigation-#{item_id}"
    )
    AuditVersion.create!(
      operation: audit_operation,
      owner_id: admin.id,
      context_id: admin.main_context.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id:,
      event: :update,
      mutation_source: :web,
      object_changes: { "description" => %w[Before After] },
      metadata: {}
    )
    audit_operation
  end

  def expect_top_level_advance(node)
    expect(node).to be_present
    expect(node["data-turbo-frame"]).to eq("_top")
    expect(node["data-turbo-action"]).to eq("advance")
  end
end
