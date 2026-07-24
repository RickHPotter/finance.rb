# frozen_string_literal: true

class HealthCheck::ChecksController < HealthCheck::BaseController
  def show
    entry = HealthCheck::Registry.find(params[:check_key])
    return head :not_found if entry.blank?

    workspace_scope = health_check_scope
    scope = workspace_scope.for_entry(entry)
    summary = summary_for(entry, scope:)
    page = entry.details.new(scope:, filters: detail_filters).call

    render Views::HealthCheck::Checks::Show.new(entry:, scope:, workspace_scope:, summary:, detail: { page: })
  rescue HealthCheck::Checks::Pending::AdapterUnavailable
    render_detail_state(entry:, scope:, workspace_scope:, summary:, state: "unavailable")
  rescue HealthCheck::Scope::Invalid
    raise
  rescue StandardError => e
    report_detail_error(e, entry:, scope:)
    render_detail_state(entry:, scope:, workspace_scope:, summary:, state: "failed")
  end

  private

  def detail_filters
    params.permit(:page, :per_page, :status_filter, :issue_filter)
  end

  def summary_for(entry, scope:)
    run = HealthCheckRun.find_by(
      user_id: scope.user.id,
      context_id: scope.context.id,
      connected_user_id: scope.connected_user&.id,
      check_key: entry.key
    )

    HealthCheck::DashboardSummary.new(entry:, run:)
  end

  def render_detail_state(entry:, scope:, workspace_scope:, summary:, state:)
    render Views::HealthCheck::Checks::Show.new(entry:, scope:, workspace_scope:, summary:, detail: { state: })
  end

  def report_detail_error(error, entry:, scope:)
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: {
        component: "health_check_details",
        check_key: entry&.key,
        user_id: scope&.user&.id,
        context_id: scope&.context&.id,
        connected_user_id: scope&.connected_user&.id
      }.compact
    )
  end
end
