# frozen_string_literal: true

class HealthCheck::DashboardController < HealthCheck::BaseController
  def show
    scope = health_check_scope
    summaries = HealthCheck::DashboardSnapshot.new(scope:).summaries

    render Views::HealthCheck::Dashboard::Show.new(scope:, summaries:)
  end
end
