# frozen_string_literal: true

class CategoryMerges::Planner
  attr_reader :actor, :context, :source_id, :destination_id

  def initialize(actor:, context:, source_id:, destination_id:)
    @actor = actor
    @context = context
    @source_id = source_id.to_i
    @destination_id = destination_id.to_i
  end

  def call
    return conflict(:context_not_owned) unless context&.user_id == actor.id
    return noop(:same_category) if source_id == destination_id

    validation_error = validate_categories
    return validation_error if validation_error

    build_plan
  end

  private

  def validate_categories
    return conflict(:source_not_found) if source.blank?
    return conflict(:destination_not_found) if destination.blank?
    return conflict(:source_inactive) unless source.active?
    return conflict(:destination_inactive) unless destination.active?
    return conflict(:source_protected) if source.built_in?
    return conflict(:destination_protected) if destination.built_in?

    nil
  end

  def build_plan
    transfer_rows = []
    collapse_rows = []
    conflict_rows = []

    source.category_transactions.includes(:transactable).find_each do |row|
      classify_row(row, transfer_rows, collapse_rows, conflict_rows, destination_category_transaction(row))
    end
    BudgetCategory.where(category: source).includes(:budget).find_each do |row|
      classify_row(row, transfer_rows, collapse_rows, conflict_rows, destination_budget_category(row))
    end

    CategoryMerges::Plan.new(
      actor:,
      context:,
      source:,
      destination:,
      outcome: conflict_rows.empty? ? :eligible : :conflict,
      transfer_rows:,
      collapse_rows:,
      conflict_rows:
    )
  end

  def classify_row(row, transfer_rows, collapse_rows, conflict_rows, destination_row)
    policy_conflict = conflict_for(row)
    if policy_conflict
      conflict_rows << row_plan(row, :conflict, policy_conflict.fetch(:reason_code), policy_conflict.fetch(:details, {}))
    elsif destination_row
      collapse_rows << row_plan(row, :collapse, nil, destination_row_id: destination_row.id)
    else
      transfer_rows << row_plan(row, :transfer)
    end
  end

  def conflict_for(row)
    reason_code = context_conflict_for(row)
    return { reason_code: } if reason_code

    category_policy_conflict_for(row)
  end

  def context_conflict_for(row)
    identity = MasterRecordMerges::AllocationOwner.resolve(row)
    return :unsupported_owner unless identity.supported?
    return :unowned_allocation unless identity.user_id == actor.id
    return :cross_context_allocation unless identity.context_id == context.id

    nil
  end

  def category_policy_conflict_for(row)
    owner = MasterRecordMerges::AllocationOwner.resolve(row).record
    return { reason_code: :subscription_owned_category, details: { subscription_id: owner.id } } if owner.is_a?(Subscription)
    return if owner.is_a?(Investment)
    return { reason_code: :unsupported_owner } unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction) || owner.is_a?(Budget)

    policy_plan = AllocationMutations::CategoryPlanner.new(owner:, action: category_action).call
    return unless policy_plan.conflict?

    {
      reason_code: policy_plan.outcome.reason_code,
      details: policy_plan.outcome.details
    }
  rescue AllocationMutations::OwnerAdapter::UnsupportedOwner
    { reason_code: :unsupported_owner }
  end

  def category_action
    @category_action ||= AllocationMutations::Action.new(
      allocation_type: :category,
      operation: :switch,
      source_id:,
      destination_id:
    )
  end

  def destination_category_transaction(row)
    CategoryTransaction.find_by(
      category: destination,
      transactable_type: row.transactable_type,
      transactable_id: row.transactable_id
    )
  end

  def destination_budget_category(row)
    BudgetCategory.find_by(category: destination, budget_id: row.budget_id)
  end

  def row_plan(row, status, reason_code = nil, details = {})
    CategoryMerges::Plan::RowPlan.new(row:, status:, reason_code:, details:)
  end

  def source
    @source ||= actor.categories.find_by(id: source_id)
  end

  def destination
    @destination ||= actor.categories.find_by(id: destination_id)
  end

  def conflict(reason_code)
    CategoryMerges::Plan.new(
      actor:,
      context:,
      source: source || stub_category(source_id),
      destination: destination || stub_category(destination_id),
      outcome: :conflict,
      reason_code:
    )
  end

  def noop(reason_code)
    CategoryMerges::Plan.new(
      actor:,
      context:,
      source: stub_category(source_id),
      destination: stub_category(destination_id),
      outcome: :noop,
      reason_code:
    )
  end

  def stub_category(id)
    Category.new.tap { |category| category.id = id }
  end
end
