# frozen_string_literal: true

class Audit::Rollback::Apply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s
      super(@reason_code)
    end
  end

  attr_reader :operation, :actor, :context, :request_id, :token, :confirmed, :token_payload

  def initialize(operation:, actor:, context:, request_id:, **options)
    @operation = operation
    @actor = actor
    @context = context
    @request_id = request_id
    @token = options.fetch(:token)
    @confirmed = ActiveModel::Type::Boolean.new.cast(options.fetch(:confirmed, false))
  end

  def call
    validate_request!
    existing_operation = existing_rollback
    return applied_result(existing_operation, duplicate: true) if existing_operation

    apply_inside_transaction
  rescue RejectedError => e
    rejected_result(e.reason_code)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, Audit::Rollback::Compensator::CompensationError
    rejected_result(:validation_failed)
  rescue Audit::Rollback::IntegrityVerifier::IntegrityError
    failed_result(:integrity_failed)
  rescue StandardError
    failed_result(:unexpected_failure)
  end

  private

  def validate_request!
    reject!(:authorization_denied) unless actor&.admin?
    @token_payload = Audit::Rollback::PreviewToken.verify(token)
    reject!(:invalid_token) unless token_payload
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
    reject!(:token_operation_mismatch) unless token_payload["operation_id"] == operation.id
  end

  def apply_inside_transaction
    result = nil
    AuditOperation.transaction do
      acquire_operation_lock!
      operation.lock!
      existing_operation = existing_rollback
      if existing_operation
        result = applied_result(existing_operation, duplicate: true)
        next
      end

      preview = locked_preview
      validate_preview!(preview)
      result = compensate!(preview)
    end
    result
  end

  def locked_preview
    provisional_preview = Audit::Rollback::Preview.new(operation: operation.reload, actor:)
    Audit::Rollback::LockSet.new(preview: provisional_preview).call
    Audit::Rollback::Preview.new(operation: operation.reload, actor:)
  end

  def validate_preview!(preview)
    reject!(:stale_preview) unless token_payload["digest"] == preview.digest
    reject!(:preview_not_applyable) unless preview.state == "previewable"
    reject!(:confirmation_required) if preview.confirmation_required? && !confirmed
  end

  def compensate!(preview)
    rollback_operation = nil
    Audit::Operation.run(
      source: :rollback,
      join_existing: false,
      actor:,
      context:,
      request_id:,
      rollback_of_operation_id: operation,
      metadata: operation_metadata
    ) do
      Audit::Operation.ensure_persisted!
      impact = Audit::Rollback::Compensator.new(preview:, confirmed:).call
      Audit::Rollback::Recalculator.new(impact:).call
      Audit::Rollback::IntegrityVerifier.new(preview:, impact:).call
      rollback_operation = Audit::Operation.ensure_persisted!
    end
    applied_result(rollback_operation, duplicate: false)
  end

  def existing_rollback
    AuditOperation.where(
      source: :rollback,
      result: :committed,
      rollback_of_operation_id: operation.id,
      actor_id: actor.id
    ).where("metadata ->> 'preview_digest' = ?", token_payload["digest"]).first
  end

  def operation_metadata
    {
      preview_digest: token_payload["digest"],
      idempotency_key: Digest::SHA256.hexdigest([ actor.id, operation.id, token_payload["digest"] ].join(":"))
    }
  end

  def acquire_operation_lock!
    connection = AuditOperation.connection
    lock_key = connection.quote("audit-rollback:#{operation.id}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end

  def reject!(reason_code)
    raise RejectedError, reason_code
  end

  def rejected_result(reason_code)
    attempt = record_attempt(result: :rejected, reason_code:)
    Audit::Rollback::ApplyResult.new(status: "rejected", operation: attempt, reason_code: reason_code.to_s, duplicate: false)
  end

  def failed_result(reason_code)
    attempt = record_attempt(result: :failed, reason_code:)
    Audit::Rollback::ApplyResult.new(status: "failed", operation: attempt, reason_code: reason_code.to_s, duplicate: false)
  end

  def record_attempt(result:, reason_code:)
    Audit::Rollback::AttemptRecorder.record!(
      actor:,
      context:,
      request_id:,
      reason_code:,
      operation:,
      result:,
      preview_digest: token_payload&.fetch("digest", nil)
    )
  end

  def applied_result(rollback_operation, duplicate:)
    Audit::Rollback::ApplyResult.new(status: "applied", operation: rollback_operation, reason_code: nil, duplicate:)
  end
end
