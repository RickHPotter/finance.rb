# frozen_string_literal: true

class Admin::AuditRollbackPreviewsController < ApplicationController
  include TabsConcern

  before_action :require_admin!
  before_action :set_audit_tabs

  def show
    operation = AuditOperation.includes(:audit_versions).find_by(id: params[:audit_operation_id])
    unless operation
      record_rejection!(:operation_not_found)
      return head :not_found
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: current_user)
    render Views::Admin::AuditRollbackPreviews::Show.new(preview:)
  end

  def create
    operation = AuditOperation.find_by(id: params[:audit_operation_id])
    unless operation
      record_rejection!(:operation_not_found)
      return head :not_found
    end

    result = Audit::Rollback::Apply.new(
      operation:,
      actor: current_user,
      context: current_context,
      request_id: request.request_id,
      token: params[:apply_token],
      confirmed: params[:historical_correction_confirmation]
    ).call

    if result.applied?
      key = result.duplicate? ? "audit.rollback.results.already_applied" : "audit.rollback.results.applied"
      redirect_to audit_operation_path(result.operation), notice: I18n.t(key), status: :see_other
    else
      redirect_to admin_audit_operation_rollback_preview_path(operation),
                  alert: I18n.t("audit.rollback.results.#{result.reason_code}"),
                  status: :see_other
    end
  end

  private

  def require_admin!
    return if current_user&.admin?

    record_rejection!(:authorization_denied)
    head :not_found
  end

  def record_rejection!(reason_code)
    Audit::Rollback::AttemptRecorder.record!(
      actor: current_user,
      context: current_context,
      request_id: request.request_id,
      reason_code:
    )
  end

  def set_audit_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :settings)
  end
end
