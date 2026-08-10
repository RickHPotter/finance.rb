# frozen_string_literal: true

class Audit::Rollback::DirectApply
  attr_reader :operation, :actor

  def initialize(operation:, actor:)
    @operation = operation
    @actor = actor
  end

  def call
    apply_inside_transaction
  end

  private

  def apply_inside_transaction
    result = nil
    AuditOperation.transaction do
      acquire_operation_lock!
      operation.lock!

      preview = locked_preview
      raise "Preview not applyable" unless preview.state == "previewable"

      result = compensate!(preview)
    end
    result
  end

  def locked_preview
    provisional_preview = Audit::Rollback::Preview.new(operation: operation.reload, actor:)
    Audit::Rollback::LockSet.new(preview: provisional_preview).call
    Audit::Rollback::Preview.new(operation: operation.reload, actor:)
  end

  def compensate!(preview)
    rollback_operation = nil
    Audit::Operation.run(
      source: :rollback,
      join_existing: true,
      actor: actor,
      rollback_of_operation_id: operation
    ) do
      Audit::Operation.ensure_persisted!
      impact = Audit::Rollback::Compensator.new(preview:, confirmed: true).call
      Audit::Rollback::Recalculator.new(impact:).call
      Audit::Rollback::IntegrityVerifier.new(preview:, impact:).call
      rollback_operation = Audit::Operation.ensure_persisted!
    end
    Audit::Rollback::ApplyResult.new(status: "applied", operation: rollback_operation, reason_code: nil, duplicate: false)
  end

  def acquire_operation_lock!
    connection = AuditOperation.connection
    lock_key = connection.quote("audit-rollback:#{operation.id}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end
end
