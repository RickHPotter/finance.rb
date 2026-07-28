# frozen_string_literal: true

class AuditOperationsController < ApplicationController
  include TabsConcern

  before_action :set_audit_tabs

  def index
    filters = audit_filter_params.to_h
    page = Audit::OperationQuery.new(reader: current_user, filters:).call
    summaries = visible_operation_summaries(page.records)

    render Views::AuditOperations::Index.new(page:, filters:, summaries:, current_user:)
  end

  def show
    operation = Audit::OperationQuery.new(reader: current_user).find(params[:id])
    return head :not_found if operation.blank?

    filters = audit_filter_params.to_h.merge("operation_id" => operation.id)
    page = Audit::VersionQuery.new(reader: current_user, filters:, order: :ascending).call

    render Views::AuditOperations::Show.new(operation:, page:, filters:, current_user:)
  end

  private

  def set_audit_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :settings)
  end

  def audit_filter_params
    params.permit(
      :operation_id, :item_type, :item_subtype, :item_id, :actor_id, :owner_id,
      :context_id, :event, :source, :mutation_source, :request_id,
      :created_from, :created_to, :page, :per_page
    )
  end

  def visible_operation_summaries(operations)
    operation_ids = operations.map(&:id)
    return {} if operation_ids.empty?

    Audit::VersionQuery.authorized_scope(current_user)
                       .where(operation_id: operation_ids)
                       .select(:operation_id, :item_type, :item_subtype)
                       .group_by(&:operation_id)
                       .transform_values do |versions|
      {
        count: versions.size,
        item_types: versions.map { |version| version.item_subtype.presence || version.item_type }.uniq.sort
      }
    end
  end
end
