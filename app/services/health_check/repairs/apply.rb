# frozen_string_literal: true

class HealthCheck::Repairs::Apply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s
      super(@reason_code)
    end
  end

  class MutationError < StandardError; end

  attr_reader :definition, :request_id, :scope, :token

  def initialize(definition:, scope:, request_id:, token:, confirmed:)
    @definition = definition
    @scope = scope
    @request_id = request_id
    @token = token
    @confirmed = ActiveModel::Type::Boolean.new.cast(confirmed)
  end

  def call
    validate_request!
    applied = apply_inside_transaction
    return applied if applied.duplicate?

    schedule = schedule_rerun(AuditOperation.find(applied.operation_id))
    applied.with(rerun_reason: schedule&.reason)
  rescue RejectedError => e
    apply_result(status: "rejected", reason_code: e.reason_code)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, MutationError
    apply_result(status: "rejected", reason_code: "validation_failed")
  rescue StandardError => e
    report(e)
    apply_result(status: "failed", reason_code: "unexpected_failure")
  end

  private

  attr_reader :token_payload

  def validate_request!
    reject!(:authorization_denied) unless scope.user.admin?
    @token_payload = HealthCheck::Repairs::PreviewToken.verify(token)
    reject!(:invalid_token) if token_payload.blank?
    reject!(:confirmation_required) unless @confirmed

    expected_token_claims.each do |reason, (claim, expected)|
      reject!(:"token_#{reason}_mismatch") unless token_payload[claim] == expected
    end
  end

  def expected_token_claims
    {
      "actor" => [ "actor_id", scope.user.id ],
      "context" => [ "context_id", scope.context.id ],
      "connection" => [ "connected_user_id", scope.connected_user&.id ],
      "check" => [ "check_key", definition.check_key ],
      "repair" => [ "repair_key", definition.key ]
    }
  end

  def apply_inside_transaction
    applied = nil
    AuditOperation.transaction do
      acquire_advisory_lock!
      existing = existing_operation
      if existing
        applied = apply_result(status: "applied", operation_id: existing.id, duplicate: true, changed_count: existing.audit_versions.count)
        next
      end

      preview = locked_preview
      validate_preview!(preview)
      operation = mutate!(preview)
      applied = apply_result(status: "applied", operation_id: operation.id, changed_count: operation.audit_versions.count)
    end
    applied
  end

  def locked_preview
    provisional = build_preview
    HealthCheck::Repairs::LockSet.new(preview: provisional).call
    build_preview
  end

  def build_preview
    result = definition.planner.new(
      scope:,
      finding_id: token_payload["finding_id"],
      options: token_payload.fetch("options", {})
    ).call
    HealthCheck::Repairs::Preview.new(
      check_key: definition.check_key,
      repair_key: definition.key,
      scope:,
      result:,
      options: token_payload.fetch("options", {})
    )
  rescue ActiveRecord::RecordNotFound
    reject!(:finding_not_current)
  end

  def validate_preview!(preview)
    reject!(:stale_preview) unless token_payload["digest"] == preview.digest
    reject!(:preview_not_applyable) unless preview.previewable?
  end

  def mutate!(preview)
    operation = nil
    Audit::Operation.run(
      source: :admin_repair,
      join_existing: false,
      actor: scope.user,
      context: scope.context,
      request_id:,
      metadata: operation_metadata(preview)
    ) do
      definition.applier.new(scope:, preview:).call
      operation = Audit::Operation.ensure_persisted!
      raise MutationError, "repair produced no audited changes" unless operation.audit_versions.exists?
    end
    operation
  end

  def operation_metadata(preview)
    {
      health_check_key: definition.check_key,
      repair_key: definition.key,
      finding_key: preview.finding_id,
      preview_digest: preview.digest,
      idempotency_key: idempotency_key
    }
  end

  def schedule_rerun(operation)
    HealthCheck::RunCoordinator.new(scope:, audit_parent_operation: operation).call(
      entries: [ HealthCheck::Registry.fetch(definition.check_key) ]
    ).first
  rescue StandardError => e
    report(e)
    nil
  end

  def existing_operation
    AuditOperation
      .where(source: :admin_repair, result: :committed, actor_id: scope.user.id, context_id: scope.context.id)
      .where("metadata ->> 'idempotency_key' = ?", idempotency_key)
      .first
  end

  def acquire_advisory_lock!
    connection = AuditOperation.connection
    lock_key = connection.quote("health-check-repair:#{idempotency_key}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end

  def idempotency_key
    @idempotency_key ||= Digest::SHA256.hexdigest(
      [ scope.user.id, scope.context.id, definition.check_key, definition.key, token_payload["finding_id"], token_payload["digest"] ].join(":")
    )
  end

  def reject!(reason_code)
    raise RejectedError, reason_code
  end

  def apply_result(**attributes)
    HealthCheck::Repairs::ApplyResult.new(**attributes)
  end

  def report(error)
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: {
        component: "health_check_repair_apply",
        check_key: definition.check_key,
        repair_key: definition.key,
        user_id: scope.user.id,
        context_id: scope.context.id
      }
    )
  rescue StandardError
    nil
  end
end
