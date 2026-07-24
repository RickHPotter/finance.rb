# frozen_string_literal: true

class HealthCheck::DashboardController < HealthCheck::BaseController
  def show
    scope = HealthCheck::Scope.new(user: current_user, context: current_context, locale: I18n.locale)
    runs_by_check = latest_runs.index_by(&:check_key)
    summaries = HealthCheck::Registry.entries.map do |entry|
      HealthCheck::DashboardSummary.new(entry:, run: runs_by_check[entry.key])
    end

    render Views::HealthCheck::Dashboard::Show.new(scope:, summaries:)
  end

  private

  def latest_runs
    current_user.health_check_runs.where(context: current_context, connected_user_id: nil)
  end
end
