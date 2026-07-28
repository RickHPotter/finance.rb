# frozen_string_literal: true

class HealthCheck::CheckRunsController < HealthCheck::BaseController
  def create
    entry = HealthCheck::Registry.find(params[:check_key])
    return head :not_found if entry.blank?

    schedule = HealthCheck::RunCoordinator.new(scope: health_check_scope).call(entries: [ entry ]).first

    redirect_to(
      check_run_destination(entry),
      status: :see_other,
      notice: check_notice(schedule)
    )
  end

  private

  def check_notice(schedule)
    key = schedule.enqueued? ? "queued" : schedule.reason
    check_title = I18n.t("health_check.checks.#{schedule.run.check_key}.title")
    I18n.t("health_check.check_runs.#{key}", check: check_title)
  end

  def check_run_destination(entry)
    return healthcheck_path(**health_check_redirect_params) unless params[:return_to] == "check"

    detail_state = params.permit(:page, :per_page, :status_filter, :issue_filter).to_h.compact_blank
    healthcheck_check_path(entry.key, **health_check_redirect_params, **detail_state)
  end
end
