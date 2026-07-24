# frozen_string_literal: true

class HealthCheck::RepairPreviewsController < HealthCheck::BaseController
  def create
    entry = HealthCheck::Registry.find(params[:check_key])
    definition = HealthCheck::Repairs::Registry.find(params[:check_key], params[:repair_key])
    return head :not_found if entry.blank? || definition.blank?

    workspace_scope = health_check_scope
    scope = workspace_scope.for_entry(entry)
    result = definition.planner.new(
      scope:,
      finding_id: params[:finding_id],
      options: preview_options
    ).call
    preview = HealthCheck::Repairs::Preview.new(
      check_key: entry.key,
      repair_key: definition.key,
      scope:,
      result:
    )

    render Views::HealthCheck::RepairPreviews::Show.new(entry:, definition:, preview:, workspace_scope:)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def preview_options
    params.permit(:strategy)
  end
end
