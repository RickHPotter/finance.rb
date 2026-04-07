# frozen_string_literal: true

class Admin::SettingsController < ApplicationController
  include TabsConcern

  before_action :require_admin!
  before_action :set_settings_tabs

  def exchange_audit
    middle_overrides = sanitized_middle_overrides
    receiver_overrides = sanitized_receiver_overrides
    selected_connected_user_id = sanitized_connected_user_id
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    rows = scope[:rows]
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:, middle_overrides:, receiver_overrides:).call

    render Views::Admin::Settings::ExchangeAudit.new(
      rows:,
      middle_overrides:,
      receiver_overrides:,
      reference_audit:,
      connections: scope[:connections],
      selected_connected_user_id: scope[:selected_connected_user_id]
    )
  end

  def apply_exchange_audit
    middle_overrides = sanitized_middle_overrides
    receiver_overrides = sanitized_receiver_overrides
    selected_connected_user_id = sanitized_connected_user_id
    source_transaction_id = params.require(:source_transaction_id).to_i
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    return head :not_found unless scope[:rows].any? { |row| row.dig(:source, :id) == source_transaction_id }

    apply_result = Logic::ExchangeChainReferenceRunner.new(
      source_transaction_ids: [ source_transaction_id ],
      dry_run: false,
      middle_overrides:,
      receiver_overrides:
    ).call
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    rows = scope[:rows]
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:, middle_overrides:, receiver_overrides:).call

    render Views::Admin::Settings::ExchangeAudit.new(
      rows:,
      middle_overrides:,
      receiver_overrides:,
      reference_audit:,
      apply_result:,
      connections: scope[:connections],
      selected_connected_user_id: scope[:selected_connected_user_id]
    )
  end

  private

  def require_admin!
    return if current_user&.admin?

    head :not_found
  end

  def set_settings_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :settings)
  end

  def audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    base_rows = Logic::ExchangeTrioAudit.new(current_user: current_user).call
    projected_rows = Logic::ExchangeAuditSelectionProjector.new(rows: base_rows, middle_overrides:, receiver_overrides:).call

    Logic::ExchangeAuditConnections.new(
      rows: projected_rows,
      current_user:,
      selected_connected_user_id:
    ).call
  end

  def sanitized_middle_overrides
    raw_middle_overrides = params[:middle_overrides]
    sanitize_override_hash(raw_middle_overrides)
  end

  def sanitized_receiver_overrides
    raw_receiver_overrides = params[:receiver_overrides]
    sanitize_override_hash(raw_receiver_overrides)
  end

  def sanitized_connected_user_id
    raw_connected_user_id = params[:connected_user_id]
    return if raw_connected_user_id.blank?

    raw_connected_user_id.to_i
  end

  def sanitize_override_hash(raw_overrides)
    overrides_hash = raw_overrides.respond_to?(:to_unsafe_h) ? raw_overrides.to_unsafe_h : raw_overrides.to_h

    overrides_hash.each_with_object({}) do |(source_id, target_id), result|
      next if source_id.blank? || target_id.blank?

      result[source_id.to_i] = target_id.to_i
    end
  end
end
