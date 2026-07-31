# frozen_string_literal: true

# Immutable value object returned by CategoryMerges::Planner.
#
# Encapsulates:
#   - The planned outcome (:eligible, :conflict, :noop) and optional reason_code
#   - Pre-computed impact counts (transaction and budget_category reassignments/deduplication)
#   - A deterministic digest that preview tokens are bound to, so Apply can detect
#     any state change between preview and execution.
class CategoryMerges::Plan
  attr_reader :actor, :source, :destination, :outcome, :reason_code, :details,
              :transaction_reassign_count, :transaction_dedup_count,
              :budget_reassign_count, :budget_dedup_count

  def initialize(
    actor:, source:, destination:, outcome:,
    reason_code: nil, details: {},
    transaction_reassign_count: 0, transaction_dedup_count: 0,
    budget_reassign_count: 0, budget_dedup_count: 0
  )
    @actor = actor
    @source = source
    @destination = destination
    @outcome = outcome
    @reason_code = reason_code
    @details = details
    @transaction_reassign_count = transaction_reassign_count
    @transaction_dedup_count = transaction_dedup_count
    @budget_reassign_count = budget_reassign_count
    @budget_dedup_count = budget_dedup_count
  end

  # @return [Boolean]
  def eligible?
    outcome == :eligible
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
    transaction_reassign_count + transaction_dedup_count
  end

  # Total BudgetCategories that exist on source (reassigned + deduplicated).
  # @return [Integer]
  def budget_total_count
    budget_reassign_count + budget_dedup_count
  end

  # Deterministic SHA-256 fingerprint of this plan's identity and impact.
  # PreviewToken embeds this digest so Apply can verify the plan hasn't changed.
  #
  # @return [String] 64-character hex digest
  def digest
    @digest ||= begin
      payload = {
        actor_id: actor.id,
        source_id: source.id,
        destination_id: destination.id,
        outcome: outcome.to_s,
        transaction_reassign_count:,
        transaction_dedup_count:,
        budget_reassign_count:,
        budget_dedup_count:
      }
      Digest::SHA256.hexdigest(AllocationMutations::Payload.canonical_json(payload))
    end
  end
end
