# frozen_string_literal: true

class AllocationMutations::Apply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s
      super(@reason_code)
    end
  end

  MODES = %w[strict eligible_only].freeze

  attr_reader :actor, :context, :request_id, :token, :mode

  def initialize(actor:, context:, token:, **options)
    @actor = actor
    @context = context
    @request_id = options[:request_id]
    @token = token
    @mode = options.fetch(:mode).to_s
    @confirmed = ActiveModel::Type::Boolean.new.cast(options.fetch(:confirmed, false))
  end

  def call
    validate_request!
    apply_inside_transaction
  rescue RejectedError => e
    result(status: :rejected, reason_code: e.reason_code)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed,
         AllocationMutations::CategoryMutator::StalePlan, AllocationMutations::EntityMutator::StalePlan
    result(status: :rejected, reason_code: :validation_failed)
  rescue StandardError => e
    report(e)
    result(status: :failed, reason_code: :unexpected_failure)
  end

  private

  attr_reader :token_payload

  def validate_request!
    reject!(:confirmation_required) unless @confirmed
    reject!(:invalid_mode) unless mode.in?(MODES)
    @token_payload = AllocationMutations::PreviewToken.verify(token)
    reject!(:invalid_token) if token_payload.blank?
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
    reject!(:token_context_mismatch) unless token_payload["context_id"] == context.id
  end

  def apply_inside_transaction
    applied = nil
    AuditOperation.transaction do
      acquire_advisory_lock!
      existing = existing_operation
      if existing
        applied = result(status: :applied, operation: existing, duplicate: true)
        next
      end

      preview = locked_preview
      validate_preview!(preview)
      applied = mutate!(preview)
    end
    applied
  end

  def locked_preview
    selection = selection_from_token
    action = action_from_token
    owners = AllocationMutations::LockSet.new(selection:, action:).call
    AllocationMutations::BatchPlanner.new(
      actor:,
      context:,
      owner_type: selection.owner_type,
      owner_ids: selection.owner_ids,
      selected_row_count: selection.selected_row_count,
      action:,
      owners:
    ).call
  rescue ActiveRecord::RecordNotFound
    reject!(:selection_not_current)
  end

  def validate_preview!(preview)
    reject!(:stale_preview) unless preview.digest == token_payload["digest"]
    if mode == "strict"
      reject!(:strict_apply_unavailable) unless preview.strict_apply_available?
    else
      reject!(:eligible_only_unavailable) unless preview.eligible_only_available?
    end
  end

  def mutate!(preview)
    impacts = []
    operation = nil
    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor:,
      context:,
      request_id:,
      metadata: operation_metadata(preview)
    ) do
      preview.plans.select(&:eligible?).each do |plan|
        impacts << mutator_class.new(plan:).call
      end
      operation = Audit::Operation.ensure_persisted!
    end
    result(status: :applied, operation:, impacts:)
  end

  def mutator_class
    action_from_token.allocation_type == :category ? AllocationMutations::CategoryMutator : AllocationMutations::EntityMutator
  end

  def selection_from_token
    @selection_from_token ||= AllocationMutations::OwnerSelection.new(
      actor:,
      context:,
      **token_payload.fetch("selection").symbolize_keys
    )
  rescue KeyError, ArgumentError
    reject!(:invalid_token)
  end

  def action_from_token
    @action_from_token ||= AllocationMutations::Action.new(**token_payload.fetch("action").symbolize_keys)
  rescue KeyError, ArgumentError
    reject!(:invalid_token)
  end

  def operation_metadata(preview)
    {
      allocation_mutation: true,
      owner_type: preview.owner_type,
      allocation_type: preview.action.allocation_type.to_s,
      action: preview.action.operation.to_s,
      source_id: preview.action.source_id,
      destination_id: preview.action.destination_id,
      mode:,
      selected_row_count: preview.selected_row_count,
      owner_count: preview.unique_owner_count,
      affected_count: preview.affected_count,
      noop_count: preview.noop_count,
      conflict_count: preview.conflict_count,
      preview_digest: preview.digest,
      idempotency_key:
    }
  end

  def existing_operation
    AuditOperation
      .where(source: :web, result: :committed, actor_id: actor.id, context_id: context.id)
      .where("metadata ->> 'idempotency_key' = ?", idempotency_key)
      .first
  end

  def acquire_advisory_lock!
    lock_key = AuditOperation.connection.quote("allocation-mutation:#{idempotency_key}")
    AuditOperation.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end

  def idempotency_key
    @idempotency_key ||= Digest::SHA256.hexdigest([ actor.id, context.id, token_payload["digest"], mode ].join(":"))
  end

  def result(**attributes)
    AllocationMutations::ApplyResult.new(mode:, **attributes)
  end

  def reject!(reason_code)
    raise RejectedError, reason_code
  end

  def report(error)
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: {
        component: "allocation_mutation_apply",
        user_id: actor&.id,
        context_id: context&.id,
        mode:
      }
    )
  rescue StandardError
    nil
  end
end
