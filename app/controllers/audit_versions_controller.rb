# frozen_string_literal: true

class AuditVersionsController < ApplicationController
  include TabsConcern

  before_action :set_audit_tabs

  def index
    filters = audit_filter_params.to_h
    filters.merge!(record_filters) if record_filter?
    page = Audit::VersionQuery.new(reader: current_user, filters:).call

    render Views::AuditVersions::Index.new(page:, filters:, current_user:, record_filter: record_filter?)
  rescue ArgumentError
    head :not_found
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

  def record_filters
    item_id = Integer(params[:item_id], exception: false)
    raise ArgumentError, "invalid audited record id" if item_id.blank?

    Audit::VersionQuery.record_filter(params[:item_type], item_id)
  end

  def record_filter?
    ActiveModel::Type::Boolean.new.cast(params[:record_filter])
  end
end
