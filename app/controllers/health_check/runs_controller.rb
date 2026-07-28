# frozen_string_literal: true

class HealthCheck::RunsController < HealthCheck::BaseController
  def create
    schedules = HealthCheck::RunCoordinator.new(scope: health_check_scope).call
    queued_count = schedules.count(&:enqueued?)

    redirect_to(
      healthcheck_path(**health_check_redirect_params),
      status: :see_other,
      notice: run_notice(schedules, queued_count:)
    )
  end

  private

  def run_notice(schedules, queued_count:)
    return I18n.t("health_check.runs.enqueue_failed") if schedules.any? { |schedule| schedule.reason == "enqueue_failed" }
    return I18n.t("health_check.runs.already_running") if queued_count.zero?

    I18n.t("health_check.runs.queued", count: queued_count)
  end
end
