# frozen_string_literal: true

# Validates eligibility and projects the impact of merging two categories.
#
# Rules enforced:
#   - source_id and destination_id must differ (noop :same_category otherwise)
#   - Both categories must be owned by actor (conflict :source_not_found / :destination_not_found)
#   - Both must be active (conflict :source_inactive / :destination_inactive)
#   - Neither may be built-in (conflict :source_protected / :destination_protected)
#
# Impact counts:
#   - transaction_reassign_count: CategoryTransactions on source whose transactable
#     does NOT already have destination → will be re-pointed to destination
#   - transaction_dedup_count:    CategoryTransactions on source whose transactable
#     ALREADY has destination → will be dropped (destination wins)
#   - budget_reassign_count:      BudgetCategories on source where the budget does
#     NOT already contain destination → will be re-pointed to destination
#   - budget_dedup_count:         BudgetCategories on source where the budget ALSO
#     has destination → will be dropped (destination wins)
#
# No writes are performed.
class CategoryMerges::Planner
  attr_reader :actor, :source_id, :destination_id

  def initialize(actor:, source_id:, destination_id:)
    @actor = actor
    @source_id = source_id.to_i
    @destination_id = destination_id.to_i
  end

  # @return [CategoryMerges::Plan]
  def call
    return noop(:same_category) if source_id == destination_id

    err = validate_categories
    return err if err

    eligible_plan
  end

  private

  # Returns a conflict Plan or nil when validation passes.
  def validate_categories
    return conflict(:source_not_found)      if source.blank?
    return conflict(:destination_not_found) if destination.blank?
    return conflict(:source_inactive)       unless source.active?
    return conflict(:destination_inactive)  unless destination.active?
    return conflict(:source_protected)      if source.built_in?
    return conflict(:destination_protected) if destination.built_in?

    nil
  end

  # --- Eligible plan ----------------------------------------------------------

  def eligible_plan
    CategoryMerges::Plan.new(
      actor:,
      source:,
      destination:,
      outcome: :eligible,
      transaction_reassign_count:,
      transaction_dedup_count:,
      budget_reassign_count:,
      budget_dedup_count:
    )
  end

  # --- Impact counts ----------------------------------------------------------

  # Source CategoryTransactions that will survive reassignment.
  def transaction_reassign_count
    @transaction_reassign_count ||= CategoryTransaction
                                    .where(category: source)
                                    .where.not(id: conflicting_ct_ids)
                                    .count
  end

  # Source CategoryTransactions whose transactable already has destination allocated.
  def transaction_dedup_count
    @transaction_dedup_count ||= conflicting_ct_ids.size
  end

  def conflicting_ct_ids
    @conflicting_ct_ids ||= CategoryTransaction
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
                            .ids
  end

  # BudgetCategories that will be reassigned (budget does not already have destination).
  def budget_reassign_count
    @budget_reassign_count ||= BudgetCategory
                               .where(category: source)
                               .where.not(budget_id: conflicting_bc_budget_ids)
                               .count
  end

  # BudgetCategories that will be dropped (budget already has destination).
  def budget_dedup_count
    @budget_dedup_count ||= conflicting_bc_budget_ids.size
  end

  def conflicting_bc_budget_ids
    @conflicting_bc_budget_ids ||= BudgetCategory
                                   .where(category: destination)
                                   .where(budget_id: BudgetCategory.where(category: source).select(:budget_id))
                                   .pluck(:budget_id)
  end

  # --- Lazy lookups -----------------------------------------------------------

  def source
    @source ||= actor.categories.find_by(id: source_id)
  end

  def destination
    @destination ||= actor.categories.find_by(id: destination_id)
  end

  # --- Outcome helpers --------------------------------------------------------

  def conflict(reason_code, details: {})
    CategoryMerges::Plan.new(
      actor:,
      source: source || stub_category(source_id),
      destination: destination || stub_category(destination_id),
      outcome: :conflict,
      reason_code:,
      details:
    )
  end

  def noop(reason_code)
    CategoryMerges::Plan.new(
      actor:,
      source: stub_category(source_id),
      destination: stub_category(destination_id),
      outcome: :noop,
      reason_code:
    )
  end

  # Returns an unsaved Category shell with a fixed id for error plans.
  def stub_category(id)
    Category.new.tap { |c| c.id = id }
  end
end
