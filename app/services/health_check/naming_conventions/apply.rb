# frozen_string_literal: true

class HealthCheck::NamingConventions::Apply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s
      super(@reason_code)
    end
  end

  class MutationError < StandardError; end

  attr_reader :request_id, :scope, :token

  def initialize(scope:, request_id:, token:, confirmed:)
    @scope = scope
    @request_id = request_id
    @token = token
    @confirmed = ActiveModel::Type::Boolean.new.cast(confirmed)
  end

  def call
    validate_request!
    apply_inside_transaction
  rescue RejectedError => e
    apply_result(status: "rejected", reason_code: e.reason_code)
  rescue ActiveRecord::RecordInvalid, MutationError
    apply_result(status: "rejected", reason_code: "validation_failed")
  rescue StandardError => e
    report(e)
    apply_result(status: "failed", reason_code: "unexpected_failure")
  end

  private

  attr_reader :token_payload

  def validate_request!
    reject!(:authorization_denied) unless scope.user.admin?
    @token_payload = HealthCheck::NamingConventions::PreviewToken.verify(token)
    reject!(:invalid_token) if token_payload.blank?
    reject!(:confirmation_required) unless @confirmed
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == scope.user.id
    reject!(:token_context_mismatch) unless token_payload["context_id"] == scope.context.id
  end

  def apply_inside_transaction
    result = nil
    CashTransaction.transaction do
      records = locked_records
      preview_results = analysis(records:).call(dry_run: true)
      digest = HealthCheck::NamingConventions::Preview.digest_for(preview_results)
      reject!(:stale_preview) unless token_payload["digest"] == digest

      result = audited_apply(records:, digest:)
    end
    result
  end

  def locked_records
    scope.context.lock!
    records = analysis.naming_scope.lock.load
    CardTransaction.where(advance_cash_transaction_id: records.map(&:id)).order(:id).lock.load
    records
  end

  def audited_apply(records:, digest:)
    results = nil
    operation = nil
    Audit::Operation.run(
      source: :admin_repair,
      join_existing: false,
      actor: scope.user,
      context: scope.context,
      request_id:,
      metadata: {
        maintenance_tool: "naming_convention",
        preview_digest: digest
      }
    ) do
      results = analysis(records:).call(dry_run: false)
      changed_count = changed_count(results)
      operation = AuditOperation.find_by(id: Audit::Current.operation_id)
      validate_operation!(operation, changed_count:)
    end

    apply_result(
      status: "applied",
      results:,
      operation_id: operation&.id,
      changed_count: changed_count(results)
    )
  end

  def validate_operation!(operation, changed_count:)
    return if changed_count.zero? && operation.blank?

    raise MutationError, "naming changes were not fully audited" unless operation&.audit_versions&.count == changed_count
  end

  def changed_count(results)
    Array(results).count { |result| result[:changes].present? }
  end

  def analysis(records: nil)
    HealthCheck::NamingConventions::Analysis.new(
      user: scope.user,
      context: scope.context,
      records:
    )
  end

  def reject!(reason_code)
    raise RejectedError, reason_code
  end

  def apply_result(**attributes)
    HealthCheck::NamingConventions::ApplyResult.new(**attributes)
  end

  def report(error)
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: {
        component: "health_check_naming_convention_apply",
        user_id: scope.user.id,
        context_id: scope.context.id
      }
    )
  rescue StandardError
    nil
  end
end
