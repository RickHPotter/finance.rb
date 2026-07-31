# frozen_string_literal: true

# Verifies a CategoryMerges::PreviewToken and executes the merge atomically.
#
# Execution order inside a single transaction + audit operation:
#   1. Verify token (actor match, not expired)
#   2. Re-run Planner with a fresh read to catch concurrent changes
#   3. Compare fresh digest against token digest → reject if stale
#   4. Delete dedup CategoryTransactions (source txns whose transactable already has destination)
#   5. Update remaining source CategoryTransactions → destination
#   6. Delete dedup BudgetCategories (budgets that have both source and destination)
#   7. Update remaining source BudgetCategories → destination
#   8. Refresh destination category counter-caches
#   9. Destroy source category
#  10. Persist AuditOperation
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

  attr_reader :actor, :context, :token, :request_id

  def initialize(actor:, token:, **options)
    @actor      = actor
    @context    = options[:context]
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

    @token_payload = CategoryMerges::PreviewToken.verify(token)
    reject!(:invalid_token)        if token_payload.blank?
    reject!(:token_actor_mismatch) unless token_payload["actor_id"] == actor.id
  end

  # --- Transaction ------------------------------------------------------------

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
    CategoryMerges::Planner.new(
      actor:,
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
      source:       :web,
      join_existing: false,
      actor:,
      context:,
      request_id:,
      metadata:     operation_metadata(plan)
    ) do
      # Pre-create the AuditOperation so BulkMutation's PaperTrail calls
      # always find a valid operation FK rather than triggering
      # create_unknown_operation! (which would persist with empty metadata).
      operation = Audit::Operation.ensure_persisted!
      merge_transactions!(source, destination)
      merge_budget_categories!(source, destination)
      destination.update_cash_transactions_count_and_total
      destination.update_card_transactions_count_and_total
      source.destroy!
    end

    result(status: :applied, operation:, plan:)
  end

  # Handles CategoryTransaction deduplication then reassignment.
  def merge_transactions!(source, destination)
    dedup_scope = CategoryTransaction
      .where(category: source)
      .where(
        "EXISTS (
          SELECT 1 FROM category_transactions ct2
          WHERE ct2.category_id = ?
            AND ct2.transactable_type = category_transactions.transactable_type
            AND ct2.transactable_id   = category_transactions.transactable_id
        )",
        destination.id
      )

    dedup_scope.find_each(&:destroy!)
    Audit::BulkMutation.update_all!(CategoryTransaction.where(category: source), category_id: destination.id)
  end

  # Handles BudgetCategory deduplication then reassignment.
  def merge_budget_categories!(source, destination)
    conflicting_budget_ids = BudgetCategory
      .where(category: destination)
      .where(budget_id: BudgetCategory.where(category: source).select(:budget_id))
      .pluck(:budget_id)

    if conflicting_budget_ids.any?
      BudgetCategory.where(category: source, budget_id: conflicting_budget_ids).find_each(&:destroy!)
    end

    Audit::BulkMutation.update_all!(BudgetCategory.where(category: source), category_id: destination.id)
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
