# frozen_string_literal: true

# Immutable value object returned by CategoryMerges::Planner.
#
# Encapsulates:
#   - The planned outcome (:eligible, :conflict, :noop) and optional reason_code
#   - Pre-computed impact counts (transaction and budget_category reassignments/deduplication)
#   - A deterministic digest that preview tokens are bound to, so Apply can detect
#     any state change between preview and execution.
class CategoryMerges::Plan
  RowPlan = Data.define(:row, :status, :reason_code, :details) do
    def eligible?
      %i[transfer collapse].include?(status)
    end

    def conflict?
      status == :conflict
    end

    def outcome
      Data.define(:reason_code).new(reason_code:)
    end
  end

  attr_reader :actor, :context, :source, :destination, :outcome, :reason_code, :details,
              :transfer_rows, :collapse_rows, :conflict_rows

  def initialize(
    actor:, context:, source:, destination:, outcome:,
    reason_code: nil, details: {},
    transfer_rows: [], collapse_rows: [], conflict_rows: []
  )
    @actor = actor
    @context = context
    @source = source
    @destination = destination
    @outcome = outcome
    @reason_code = reason_code
    @details = details
    @transfer_rows = transfer_rows
    @collapse_rows = collapse_rows
    @conflict_rows = conflict_rows
  end

  # @return [Boolean]
  def eligible?
    outcome == :eligible && conflict_rows.empty?
  end

  # @return [Boolean]
  def conflict?
    outcome == :conflict
  end

  # @return [Boolean]
  def noop?
    outcome == :noop
  end

  # Total CategoryTransactions that exist on source (reassigned + deduplicated).
  # @return [Integer]
  def transaction_total_count
    transaction_reassign_count + transaction_dedup_count + transaction_conflict_count
  end

  def transaction_reassign_count
    transfer_rows.count { |row_plan| row_plan.row.is_a?(CategoryTransaction) }
  end

  def transaction_dedup_count
    collapse_rows.count { |row_plan| row_plan.row.is_a?(CategoryTransaction) }
  end

  def transaction_conflict_count
    conflict_rows.count { |row_plan| row_plan.row.is_a?(CategoryTransaction) }
  end

  def budget_reassign_count
    transfer_rows.count { |row_plan| row_plan.row.is_a?(BudgetCategory) }
  end

  def budget_dedup_count
    collapse_rows.count { |row_plan| row_plan.row.is_a?(BudgetCategory) }
  end

  def budget_conflict_count
    conflict_rows.count { |row_plan| row_plan.row.is_a?(BudgetCategory) }
  end

  # Total BudgetCategories that exist on source (reassigned + deduplicated).
  # @return [Integer]
  def budget_total_count
    budget_reassign_count + budget_dedup_count + budget_conflict_count
  end

  def row_plans
    @row_plans ||= transfer_rows + collapse_rows + conflict_rows
  end

  # Deterministic SHA-256 fingerprint of this plan's identity and impact.
  # PreviewToken embeds this digest so Apply can verify the plan hasn't changed.
  #
  # @return [String] 64-character hex digest
  def digest
    @digest ||= begin
      payload = {
        actor_id: actor.id,
        context_id: context&.id,
        source_id: source.id,
        destination_id: destination.id,
        outcome: outcome.to_s,
        reason_code: reason_code.to_s,
        source_state: master_state(source),
        destination_state: master_state(destination),
        rows: row_plans.map { |row_plan| row_fingerprint(row_plan) }.sort_by { |row| [ row[:record_type], row[:record_id] ] }
      }
      Digest::SHA256.hexdigest(AllocationMutations::Payload.canonical_json(payload))
    end
  end

  private

  def master_state(record)
    record.attributes.slice("id", "user_id", "active", "built_in")
  end

  def row_fingerprint(row_plan)
    {
      record_type: row_plan.row.class.base_class.name,
      record_id: row_plan.row.id,
      status: row_plan.status.to_s,
      reason_code: row_plan.reason_code.to_s,
      details: row_plan.details
    }
  end
end
