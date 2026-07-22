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
