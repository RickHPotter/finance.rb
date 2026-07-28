# frozen_string_literal: true

class HealthCheck::RepairsController < HealthCheck::BaseController
  def update
    entry = HealthCheck::Registry.find(params[:check_key])
    definition = HealthCheck::Repairs::Registry.find(params[:check_key], params[:repair_key])
    return head :not_found if entry.blank? || definition.blank?

    workspace_scope = health_check_scope
    scope = workspace_scope.for_entry(entry)
    result = HealthCheck::Repairs::Apply.new(
      definition:,
      scope:,
      request_id: request.request_id,
      token: params[:apply_token],
      confirmed: params[:repair_confirmation]
    ).call
    summary = HealthCheck::DashboardSnapshot.new(scope: workspace_scope).summaries.find { |candidate| candidate.entry == entry }

    render Views::HealthCheck::Repairs::Show.new(entry:, result:, summary:, workspace_scope:), status: response_status(result)
  end

  private

  def response_status(result)
    return :ok if result.applied?
    return :unprocessable_content if result.rejected?

    :internal_server_error
  end
end
