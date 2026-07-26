# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check and audit Turbo navigation", type: :feature do
  let(:admin) { create(:user, :random, admin: true) }
  let!(:operation) do
    audit_operation = AuditOperation.create!(
      source: :web,
      result: :committed,
      actor_id: admin.id,
      context_id: admin.main_context.id,
      request_id: "operational-navigation"
    )
    AuditVersion.create!(
      operation: audit_operation,
      owner_id: admin.id,
      context_id: admin.main_context.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: 101,
      event: :update,
      mutation_source: :web,
      object_changes: { "description" => %w[Before After] },
      metadata: {}
    )
    audit_operation
  end

  before { sign_in admin }

  it "advances through Health Check, version history, and an operation without cycling stale URLs" do
    visit healthcheck_path
    refresh_browser_at(healthcheck_path)

    find("a[href='#{audit_operations_path}']", match: :first).click
    expect_browser_path(audit_operations_path)

    find("a[href='#{audit_versions_path}']", match: :first).click
    expect_browser_path(audit_versions_path)
    refresh_browser_at(audit_versions_path)

    find("a[href='#{audit_operation_path(operation)}']", match: :first).click
    expect_browser_path(audit_operation_path(operation))
    refresh_browser_at(audit_operation_path(operation))

    preview_path = admin_audit_operation_rollback_preview_path(operation)
    find("a[href='#{preview_path}']", match: :first).click
    expect_browser_path(preview_path)
    refresh_browser_at(preview_path)
    browser_back_to(audit_operation_path(operation))

    find("#audit_health_check_link").click
    expect_browser_path(healthcheck_path)

    browser_back_to(audit_operation_path(operation))
    browser_back_to(audit_versions_path)
    browser_forward_to(audit_operation_path(operation))
    refresh_browser_at(audit_operation_path(operation))
  end

  it "keeps a local check rerun on its refreshable detail URL" do
    detail_path = healthcheck_check_path("piggy_bank", status_filter: "pending", per_page: 25)

    visit detail_path
    expect_browser_path(detail_path)
    find("a[data-turbo-method='post'][href*='/healthcheck/checks/piggy_bank/run']", match: :first).click

    expect_browser_path(detail_path)
    expect(page).to have_text(I18n.t("health_check.checks.piggy_bank.title"))
    refresh_browser_at(detail_path)
  end
end
