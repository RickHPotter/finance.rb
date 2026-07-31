# frozen_string_literal: true

# Verifies a EntityMerges::PreviewToken and executes the merge atomically.
# Supports :strict (all-or-nothing) and :eligible_only modes.
class EntityMerges::Apply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s
      super(@reason_code)
    end
  end

  Result = Data.define(:status, :reason_code, :operation, :plan) do
    def applied?
      status == :applied
    end

    def rejected?
      status == :rejected
    end
  end

  attr_reader :actor, :context, :token, :request_id

  def initialize(actor:, token:, **options)
    @actor      = actor
    @context    = options[:context]
    @token      = token
    @request_id = options[:request_id]
    @confirmed  = ActiveModel::Type::Boolean.new.cast(options.fetch(:confirmed, false))
    @mode       = options[:mode]&.to_sym || :strict
  end

  def call
    validate_request!
    apply_inside_transaction
  rescue RejectedError => e
    result(status: :rejected, reason_code: e.reason_code)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
    result(status: :rejected, reason_code: :validation_failed)
  rescue StandardError => e
    Rails.logger.error("💥 APPLY CRASH 💥: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    report(e)
    result(status: :failed, reason_code: :unexpected_failure)
  end

  private

  attr_reader :token_payload, :mode

  def validate_request!
    reject!(:confirmation_required) unless @confirmed

    @token_payload = EntityMerges::PreviewToken.verify(token)
    reject!(:invalid_token)        if token_payload.blank?
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
  end

  def apply_inside_transaction
    applied = nil
    ApplicationRecord.transaction do
      plan = fresh_plan
      validate_plan!(plan)
      applied = execute_merge!(plan)
    end
    applied
  end

  def fresh_plan
    EntityMerges::Planner.new(
      actor:,
      source_id: token_payload["source_id"],
      destination_id: token_payload["destination_id"],
      mode: mode # Use the requested mode, not necessarily the token's mode, because the token just proves the digests match the source state
    ).call
  rescue ActiveRecord::RecordNotFound
    reject!(:source_not_found)
  end

  def validate_plan!(plan)
    # The token digest contains the mode it was planned with. We must check the digest of a plan run with that mode.
    # Wait, the apply request passes the chosen mode (strict or eligible_only). The token was signed with the mode from the preview.
    # We should trust the mode the user chose, but we need to ensure the underlying state hasn't changed.
    # So we compare the digest of the fresh plan matching the token's mode.
    token_mode = token_payload["mode"].to_sym

    # If the user is submitting eligible_only, we check if the plan is actually available for eligible_only.
    # The digest check is strictly to ensure the rows haven't changed.
    digest_plan = if mode == token_mode
                    plan
                  else
                    EntityMerges::Planner.new(
                      actor:,
                      source_id: token_payload["source_id"],
                      destination_id: token_payload["destination_id"],
                      mode: token_mode
                    ).call
                  end

    reject!(:stale_preview) unless digest_plan.digest == token_payload["digest"]
    reject!(:merge_ineligible) unless plan.apply_available?
  end

  def execute_merge!(plan)
    operation = nil

    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor:,
      context:,
      request_id:,
      metadata: operation_metadata(plan)
    ) do
      operation = Audit::Operation.ensure_persisted!

      collapse_planned_rows(plan)
      transfer_planned_rows(plan)
      update_counters(plan.source, plan.destination)
      cleanup_source(plan.source)
    end

    result(status: :applied, operation:, plan:)
  end

  def collapse_planned_rows(plan)
    grouped = plan.collapse_rows.group_by { |rp| rp.row.class }

    if (et_ids = grouped[EntityTransaction]&.map { |rp| rp.row.id })
      EntityTransaction.where(id: et_ids).find_each(&:destroy!)
    end

    if (be_ids = grouped[BudgetEntity]&.map { |rp| rp.row.id })
      BudgetEntity.where(id: be_ids).find_each(&:destroy!)
    end
  end

  def transfer_planned_rows(plan)
    grouped = plan.transfer_rows.group_by { |rp| rp.row.class }
    dest_id = plan.destination.id

    if (et_ids = grouped[EntityTransaction]&.map { |rp| rp.row.id })
      Audit::BulkMutation.update_all!(EntityTransaction.where(id: et_ids), entity_id: dest_id)
    end

    if (be_ids = grouped[BudgetEntity]&.map { |rp| rp.row.id })
      Audit::BulkMutation.update_all!(BudgetEntity.where(id: be_ids), entity_id: dest_id)
    end
  end

  def update_counters(source, destination)
    destination.update_cash_transactions_count_and_total
    destination.update_card_transactions_count_and_total
    source.update_cash_transactions_count_and_total
    source.update_card_transactions_count_and_total
  end

  def cleanup_source(source)
    source.destroy! unless EntityTransaction.exists?(entity_id: source.id) || BudgetEntity.exists?(entity_id: source.id)
  end

  def operation_metadata(plan)
    source_destroyed = plan.mode == :strict || plan.conflict_rows.empty?
    remaining_count = source_destroyed ? 0 : plan.conflict_rows.size

    {
      entity_merge: true,
      source_id: plan.source.id,
      destination_id: plan.destination.id,
      mode: plan.mode.to_s,
      transaction_reassign_count: plan.transaction_reassign_count,
      transaction_dedup_count: plan.transaction_dedup_count,
      budget_reassign_count: plan.budget_reassign_count,
      budget_dedup_count: plan.budget_dedup_count,
      preview_digest: plan.digest,
      source_destroyed:,
      remaining_count:
    }
  end

  def result(status:, reason_code: nil, operation: nil, plan: nil)
    Result.new(status:, reason_code:, operation:, plan:)
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
        component: "entity_merge_apply",
        user_id: actor&.id,
        context_id: context&.id
      }
    )
  rescue StandardError
    nil
  end
end
