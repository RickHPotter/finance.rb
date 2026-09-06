# frozen_string_literal: true

# Verifies a CategoryMerges::PreviewToken and executes the merge atomically.
#
# Execution order inside a single transaction + audit operation:
#   1. Verify token (actor match, not expired)
#   2. Serialize the category pair and lock both masters in ID order
#   3. Inventory and lock the exact source and duplicate-destination joins
#   4. Re-plan under lock and reject any digest drift
#   5. Transfer or collapse only the previewed joins
#   6. Refresh and validate affected Budgets and the final allocation graph
#   7. Destroy the source and recalculate allocation totals and Budget balances
#   8. Persist the AuditOperation
#
# All write operations use Audit::BulkMutation helpers so PaperTrail versions are
# recorded for every row touched, maintaining full financial audit trail.
class CategoryMerges::Apply
  # Raised internally when a validation step fails; caught in #call.
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
  end

  # @return [CategoryMerges::Apply::Result]
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

  attr_reader :token_payload

  # --- Request validation -----------------------------------------------------

  def validate_request!
    reject!(:confirmation_required) unless @confirmed
    reject!(:context_not_owned) unless context&.user_id == actor.id

    @token_payload = CategoryMerges::PreviewToken.verify(token)
    reject!(:invalid_token)        if token_payload.blank?
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
    reject!(:token_context_mismatch) unless token_payload["context_id"] == context.id
    reject!(:token_source_mismatch) unless token_payload["source_id"] == source_id
    reject!(:invalid_mode) unless token_payload["mode"] == "strict"
  end

  # --- Transaction ------------------------------------------------------------

  def apply_inside_transaction
    applied = nil
    ApplicationRecord.transaction do
      acquire_advisory_lock!
      lock_categories!
      lock_planned_rows!(fresh_plan)
      plan = fresh_plan
      validate_plan!(plan)
      applied = execute_merge!(plan)
    end
    applied
  end

  def fresh_plan
    CategoryMerges::Planner.new(
      actor:,
      context:,
      source_id: token_payload["source_id"],
      destination_id: token_payload["destination_id"]
    ).call
  rescue ActiveRecord::RecordNotFound
    reject!(:source_not_found)
  end

  def validate_plan!(plan)
    reject!(:stale_preview) unless plan.digest == token_payload["digest"]
    reject!(:merge_ineligible) unless plan.eligible?
  end

  # --- Merge ------------------------------------------------------------------

  def execute_merge!(plan)
    source      = plan.source
    destination = plan.destination
    operation   = nil

    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor:,
      context:,
      request_id:,
      metadata: operation_metadata(plan)
    ) do
      # Pre-create the AuditOperation so BulkMutation's PaperTrail calls
      # always find a valid operation FK rather than triggering
      # create_unknown_operation! (which would persist with empty metadata).
      operation = Audit::Operation.ensure_persisted!
      impacts = impacts_before_merge(plan)
      apply_exact_rows!(plan, destination)
      refresh_affected_budgets!(plan, impacts)
      validate_final_graph!(plan, destination)
      source.destroy!
      AllocationMutations::ImpactRecalculator.new(actor:, context:, impacts:).call
    end

    result(status: :applied, operation:, plan:)
  end

  def apply_exact_rows!(plan, destination)
    destroy_exact_rows!(plan.collapse_rows)
    transfer_exact_rows!(plan.transfer_rows, destination)
  end

  def destroy_exact_rows!(row_plans)
    row_plans.group_by { |row_plan| row_plan.row.class.base_class }.each do |model, plans|
      model.where(id: plans.map { |row_plan| row_plan.row.id }).order(:id).each(&:destroy!)
    end
  end

  def transfer_exact_rows!(row_plans, destination)
    row_plans.group_by { |row_plan| row_plan.row.class.base_class }.each do |model, plans|
      Audit::BulkMutation.update_all!(model.where(id: plans.map { |row_plan| row_plan.row.id }), category_id: destination.id)
    end
  end

  def impacts_before_merge(plan)
    policy_owners(plan).filter_map do |owner|
      next unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction) || owner.is_a?(Budget)

      category_ids_before = AllocationMutations::OwnerAdapter.for(owner).category_ids
      AllocationMutations::Impact.build(
        owner:,
        category_ids_before:,
        category_ids_after: (category_ids_before - [ plan.source.id ]) | [ plan.destination.id ]
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
    plan.row_plans.filter_map { |row_plan| MasterRecordMerges::AllocationOwner.resolve(row_plan.row).record }.uniq { |owner| [ owner.class.base_class.name, owner.id ] }
  end

  def validate_final_graph!(plan, destination)
    reject!(:stale_preview) if CategoryTransaction.where(category_id: plan.source.id).exists? || BudgetCategory.where(category_id: plan.source.id).exists?

    plan.row_plans.each do |row_plan|
      row = row_plan.row.class.base_class.find_by(id: row_plan.row.id)
      if row_plan.status == :collapse
        reject!(:validation_failed) if row.present?
      elsif row.blank? || row.category_id != destination.id
        reject!(:validation_failed)
      end
    end

    validate_category_transaction_uniqueness!(plan)
    validate_budget_category_uniqueness!(plan)
  end

  def validate_category_transaction_uniqueness!(plan)
    owner_keys = plan.row_plans.filter_map do |row_plan|
      row = row_plan.row
      [ row.transactable_type, row.transactable_id ] if row.is_a?(CategoryTransaction)
    end
    duplicates = owner_keys.any? do |transactable_type, transactable_id|
      CategoryTransaction.where(category_id: plan.destination.id, transactable_type:, transactable_id:).count != 1
    end
    reject!(:validation_failed) if duplicates
  end

  def validate_budget_category_uniqueness!(plan)
    budget_ids = plan.row_plans.filter_map { |row_plan| row_plan.row.budget_id if row_plan.row.is_a?(BudgetCategory) }
    duplicates = budget_ids.any? { |budget_id| BudgetCategory.where(category_id: plan.destination.id, budget_id:).count != 1 }
    reject!(:validation_failed) if duplicates
  end

  # --- Locking ---------------------------------------------------------------

  def acquire_advisory_lock!
    connection = Category.connection
    category_ids = [ token_payload["source_id"], token_payload["destination_id"] ].sort.join(":")
    lock_key = connection.quote("category-merge:#{actor.id}:#{context.id}:#{category_ids}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end

  def lock_categories!
    locked_ids = Category.where(id: [ token_payload["source_id"], token_payload["destination_id"] ]).order(:id).lock.ids
    reject!(:stale_preview) unless locked_ids.sort == [ token_payload["source_id"], token_payload["destination_id"] ].sort
  end

  def lock_planned_rows!(plan)
    lock_row_model!(CategoryTransaction, plan)
    lock_row_model!(BudgetCategory, plan)
  end

  def lock_row_model!(model, plan)
    row_ids = plan.row_plans.filter_map { |row_plan| row_plan.row.id if row_plan.row.is_a?(model) }
    destination_ids = plan.row_plans.filter_map { |row_plan| row_plan.details[:destination_row_id] if row_plan.row.is_a?(model) }
    model.where(id: row_ids + destination_ids).order(:id).lock.load
  end

  # --- Audit metadata ---------------------------------------------------------

  def operation_metadata(plan)
    {
      category_merge: true,
      source_id: plan.source.id,
      destination_id: plan.destination.id,
      transaction_reassign_count: plan.transaction_reassign_count,
      transaction_dedup_count: plan.transaction_dedup_count,
      budget_reassign_count: plan.budget_reassign_count,
      budget_dedup_count: plan.budget_dedup_count,
      preview_digest: plan.digest
    }
  end

  # --- Helpers ----------------------------------------------------------------

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
        component: "category_merge_apply",
        user_id: actor&.id,
        context_id: context&.id
      }
    )
  rescue StandardError
    nil
  end
end
