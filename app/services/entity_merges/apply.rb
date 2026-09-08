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

  attr_reader :actor, :context, :source_id, :token, :request_id

  def initialize(actor:, context:, source_id:, token:, **options)
    @actor      = actor
    @context    = context
    @source_id  = source_id.to_i
    @token      = token
    @request_id = options[:request_id]
    @confirmed  = ActiveModel::Type::Boolean.new.cast(options.fetch(:confirmed, false))
    @mode       = options[:mode]&.to_sym
  end

  def call
    validate_request!
    apply_inside_transaction
  rescue RejectedError => e
    result(status: :rejected, reason_code: e.reason_code)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
    result(status: :rejected, reason_code: :validation_failed)
  rescue StandardError => e
    report(e)
    result(status: :failed, reason_code: :unexpected_failure)
  end

  private

  attr_reader :token_payload, :mode

  def validate_request!
    reject!(:confirmation_required) unless @confirmed
    reject!(:context_not_owned) unless context&.user_id == actor.id
    reject!(:invalid_mode) unless mode.in?(EntityMerges::Planner::VALID_MODES)

    @token_payload = EntityMerges::PreviewToken.verify(token)
    validate_token_scope!
  end

  def validate_token_scope!
    reject!(:invalid_token) if token_payload.blank?
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
    reject!(:token_context_mismatch) unless token_payload["context_id"] == context.id
    reject!(:token_source_mismatch) unless token_payload["source_id"] == source_id
    reject!(:token_mode_mismatch) unless token_payload["mode"] == mode.to_s
  end

  def apply_inside_transaction
    applied = nil
    ApplicationRecord.transaction do
      acquire_advisory_lock!
      lock_entities!
      lock_planned_rows!(fresh_plan)
      plan = fresh_plan
      validate_plan!(plan)
      applied = execute_merge!(plan)
    end
    applied
  end

  def fresh_plan
    EntityMerges::Planner.new(
      actor:,
      context:,
      source_id: token_payload["source_id"],
      destination_id: token_payload["destination_id"],
      mode:
    ).call
  rescue ActiveRecord::RecordNotFound
    reject!(:source_not_found)
  end

  def validate_plan!(plan)
    reject!(:stale_preview) unless plan.digest == token_payload["digest"]
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
      impacts = impacts_before_merge(plan)
      collapse_planned_rows(plan)
      transfer_planned_rows(plan)
      refresh_affected_budgets!(plan, impacts)
      validate_final_graph!(plan)
      cleanup_source(plan.source)
      AllocationMutations::ImpactRecalculator.new(actor:, context:, impacts:).call
    end

    result(status: :applied, operation:, plan:)
  end

  def collapse_planned_rows(plan)
    plan.collapse_rows.group_by { |row_plan| row_plan.row.class.base_class }.each do |model, plans|
      model.where(id: plans.map { |row_plan| row_plan.row.id }).order(:id).each(&:destroy!)
    end
  end

  def transfer_planned_rows(plan)
    plan.transfer_rows.group_by { |row_plan| row_plan.row.class.base_class }.each do |model, plans|
      Audit::BulkMutation.update_all!(model.where(id: plans.map { |row_plan| row_plan.row.id }), entity_id: plan.destination.id)
    end
  end

  def impacts_before_merge(plan)
    policy_owners(plan).filter_map do |owner|
      next unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction) || owner.is_a?(Budget)

      entity_ids_before = AllocationMutations::OwnerAdapter.for(owner).entity_ids
      AllocationMutations::Impact.build(
        owner:,
        entity_ids_before:,
        entity_ids_after: (entity_ids_before - [ plan.source.id ]) | [ plan.destination.id ]
      )
    end
  end

  def refresh_affected_budgets!(plan, impacts)
    budget_impacts = impacts.select { |impact| impact.owner_type == "Budget" }.index_by(&:owner_id)
    policy_owners(plan).grep(Budget).each do |budget|
      inputs_before = [ budget.value, budget.remaining_value ]
      budget.reload
      budget.refresh_description_from_allocations
      budget.recalculate_balance = false
      budget.save!
      impact = budget_impacts.fetch(budget.id)
      budget_impacts[budget.id] = impact.with(balance_recalculation_required: inputs_before != [ budget.value, budget.remaining_value ])
    end

    impacts.replace(
      impacts.map do |impact|
        impact.owner_type == "Budget" ? budget_impacts.fetch(impact.owner_id) : impact
      end
    )
  end

  def policy_owners(plan)
    (plan.transfer_rows + plan.collapse_rows)
      .filter_map { |row_plan| MasterRecordMerges::AllocationOwner.resolve(row_plan.row).record }
      .uniq { |owner| [ owner.class.base_class.name, owner.id ] }
  end

  def validate_final_graph!(plan)
    validate_planned_rows!(plan)
    validate_source_rows!(plan)
    validate_destination_uniqueness!(plan)
  end

  def validate_planned_rows!(plan)
    (plan.transfer_rows + plan.collapse_rows).each do |row_plan|
      row = row_plan.row.class.base_class.find_by(id: row_plan.row.id)
      if row_plan.status == :collapse
        reject!(:validation_failed) if row.present?
      elsif row.blank? || row.entity_id != plan.destination.id
        reject!(:validation_failed)
      end
    end
  end

  def validate_source_rows!(plan)
    expected = plan.conflict_rows.group_by { |row_plan| row_plan.row.class.base_class }.transform_values { |plans| plans.map { |row_plan| row_plan.row.id }.sort }
    actual = {
      EntityTransaction => EntityTransaction.where(entity_id: plan.source.id).order(:id).ids,
      BudgetEntity => BudgetEntity.where(entity_id: plan.source.id).order(:id).ids
    }
    reject!(:stale_preview) unless actual.all? { |model, ids| ids == expected.fetch(model, []) }
  end

  def validate_destination_uniqueness!(plan)
    transaction_keys = (plan.transfer_rows + plan.collapse_rows).filter_map do |row_plan|
      row = row_plan.row
      [ row.transactable_type, row.transactable_id ] if row.is_a?(EntityTransaction)
    end
    duplicate_transaction = transaction_keys.any? do |transactable_type, transactable_id|
      EntityTransaction.where(entity_id: plan.destination.id, transactable_type:, transactable_id:).count != 1
    end

    budget_ids = (plan.transfer_rows + plan.collapse_rows).filter_map { |row_plan| row_plan.row.budget_id if row_plan.row.is_a?(BudgetEntity) }
    duplicate_budget = budget_ids.any? { |budget_id| BudgetEntity.where(entity_id: plan.destination.id, budget_id:).count != 1 }
    reject!(:validation_failed) if duplicate_transaction || duplicate_budget
  end

  def cleanup_source(source)
    source.destroy! unless EntityTransaction.exists?(entity_id: source.id) || BudgetEntity.exists?(entity_id: source.id)
  end

  # --- Locking ---------------------------------------------------------------

  def acquire_advisory_lock!
    connection = Entity.connection
    entity_ids = [ token_payload["source_id"], token_payload["destination_id"] ].sort.join(":")
    lock_key = connection.quote("entity-merge:#{actor.id}:#{context.id}:#{entity_ids}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end

  def lock_entities!
    locked_ids = Entity.where(id: [ token_payload["source_id"], token_payload["destination_id"] ]).order(:id).lock.ids
    reject!(:stale_preview) unless locked_ids.sort == [ token_payload["source_id"], token_payload["destination_id"] ].sort
  end

  def lock_planned_rows!(plan)
    lock_row_model!(EntityTransaction, plan)
    lock_row_model!(BudgetEntity, plan)
  end

  def lock_row_model!(model, plan)
    row_ids = plan.row_plans.filter_map { |row_plan| row_plan.row.id if row_plan.row.is_a?(model) }
    destination_ids = plan.row_plans.filter_map { |row_plan| row_plan.details[:destination_row_id] if row_plan.row.is_a?(model) }
    model.where(id: row_ids + destination_ids).order(:id).lock.load
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
