# frozen_string_literal: true

class AllocationMutations::CategoryPlanner
  attr_reader :owner, :action, :adapter

  def initialize(owner:, action:)
    @owner = owner
    @action = action
    @adapter = AllocationMutations::OwnerAdapter.for(owner)
  end

  def call
    raise ArgumentError, "category action required" unless category_action?

    category_error = validate_categories
    return conflict(**category_error) if category_error.present?
    return noop(:same_category) if action.switch? && action.source_id == action.destination_id

    category_ids_after, noop_reason = projected_category_ids
    return noop(noop_reason) if noop_reason.present?

    final_state_error = validate_final_state(category_ids_after)
    return conflict(**final_state_error) if final_state_error.present?

    plan(AllocationMutations::Outcome.eligible(owner:, reason_code: :ready), category_ids_after:)
  end

  private

  def category_action?
    action.is_a?(AllocationMutations::Action) && action.allocation_type == :category
  end

  def validate_categories
    requested_category_ids.each do |category_id|
      category = requested_categories[category_id]
      return { reason_code: :category_not_owned, details: { category_id: } } if category.blank?
      return { reason_code: :category_inactive, details: { category_id: } } unless category.active?
      return { reason_code: :category_protected, details: { category_id: } } if category.built_in?
    end

    validate_subscription_categories
  end

  def validate_subscription_categories
    return unless owner.respond_to?(:subscription) && owner.subscription.present?

    inherited_ids = owner.subscription.category_ids
    protected_id = requested_category_ids.find { |category_id| inherited_ids.include?(category_id) }
    return if protected_id.blank?

    { reason_code: :subscription_owned_category, details: { category_id: protected_id } }
  end

  def projected_category_ids
    return projected_add_ids if action.add?
    return projected_remove_ids if action.remove?

    projected_switch_ids
  end

  def projected_add_ids
    return [ category_ids_before, :destination_present ] if category_ids_before.include?(action.destination_id)

    [ category_ids_before + [ action.destination_id ], nil ]
  end

  def projected_remove_ids
    return [ category_ids_before, :source_absent ] unless category_ids_before.include?(action.source_id)

    [ category_ids_before - [ action.source_id ], nil ]
  end

  def projected_switch_ids
    return [ category_ids_before, :source_absent ] unless category_ids_before.include?(action.source_id)

    [ (category_ids_before - [ action.source_id ]) | [ action.destination_id ], nil ]
  end

  def validate_final_state(category_ids_after)
    return validate_budget_final_state(category_ids_after) if owner.is_a?(Budget)

    nil
  end

  def validate_budget_final_state(category_ids_after)
    final_state = AllocationMutations::BudgetFinalState.new(
      budget: owner,
      category_ids: category_ids_after,
      entity_ids: adapter.entity_ids
    )
    return if final_state.valid?

    {
      reason_code: :invalid_final_state,
      details: { errors: final_state.errors }
    }
  end

  def requested_category_ids
    @requested_category_ids ||= [ action.source_id, action.destination_id ].compact.uniq
  end

  def requested_categories
    @requested_categories ||= owner.user.categories.where(id: requested_category_ids).index_by(&:id)
  end

  def category_ids_before
    @category_ids_before ||= adapter.category_ids
  end

  def conflict(reason_code:, details: {})
    plan(AllocationMutations::Outcome.conflict(owner:, reason_code:, details:), category_ids_after: category_ids_before)
  end

  def noop(reason_code)
    plan(AllocationMutations::Outcome.noop(owner:, reason_code:), category_ids_after: category_ids_before)
  end

  def plan(outcome, category_ids_after:)
    AllocationMutations::CategoryPlan.new(
      owner:,
      action:,
      outcome:,
      category_ids_before:,
      category_ids_after:
    )
  end
end
