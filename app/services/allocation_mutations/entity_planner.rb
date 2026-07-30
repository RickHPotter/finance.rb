# frozen_string_literal: true

class AllocationMutations::EntityPlanner
  STRUCTURAL_FAMILIES = %i[
    borrow_return
    card_advance
    card_installment
    card_payment
    exchange
    exchange_return
    failed_return
    generated_projection
    investment
    piggy_bank
    piggy_bank_return
  ].freeze

  attr_reader :owner, :action, :adapter

  def initialize(owner:, action:)
    @owner = owner
    @action = action
    @adapter = AllocationMutations::OwnerAdapter.for(owner)
  end

  def call
    raise ArgumentError, "entity action required" unless entity_action?

    entity_error = validate_entities
    return conflict(**entity_error) if entity_error.present?
    return noop(:same_entity) if action.switch? && action.source_id == action.destination_id

    entity_ids_after, noop_reason = projected_entity_ids
    return noop(noop_reason) if noop_reason.present?

    structural_error = validate_owner_structure
    return conflict(**structural_error) if structural_error.present?

    neutrality_error = validate_source_neutrality
    return conflict(**neutrality_error) if neutrality_error.present?

    final_state_error = validate_final_state(entity_ids_after)
    return conflict(**final_state_error) if final_state_error.present?

    plan(AllocationMutations::Outcome.eligible(owner:, reason_code: :ready), entity_ids_after:)
  end

  private

  def entity_action?
    action.is_a?(AllocationMutations::Action) && action.allocation_type == :entity
  end

  def validate_entities
    requested_entity_ids.each do |entity_id|
      entity = requested_entities[entity_id]
      return { reason_code: :entity_not_owned, details: { entity_id: } } if entity.blank?
      return { reason_code: :entity_inactive, details: { entity_id: } } unless entity.active?
      return { reason_code: :entity_protected, details: { entity_id: } } if entity.built_in? || entity.entity_user_id.present?
    end

    nil
  end

  def validate_owner_structure
    return validate_subscription_structure if subscription_managed?
    return unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction)

    family = AllocationMutations::StructuralFamily.call(owner)
    protected_family = family.find { |code| STRUCTURAL_FAMILIES.include?(code) }
    return if protected_family.blank?

    { reason_code: :structural_entity_allocation, details: { family: protected_family } }
  end

  def validate_subscription_structure
    { reason_code: :subscription_owned_entity, details: { subscription_id: owner.subscription_id } }
  end

  def subscription_managed?
    return false unless owner.respond_to?(:subscription) && owner.subscription.present?

    subscription_entity_ids = owner.subscription.entity_ids
    current_entity_ids = adapter.entity_ids
    current_entity_ids.intersect?(subscription_entity_ids)
  end

  def projected_entity_ids
    return projected_add_ids if action.add?
    return projected_remove_ids if action.remove?

    projected_switch_ids
  end

  def projected_add_ids
    return [ entity_ids_before, :destination_present ] if entity_ids_before.include?(action.destination_id)

    [ entity_ids_before + [ action.destination_id ], nil ]
  end

  def projected_remove_ids
    return [ entity_ids_before, :source_absent ] unless entity_ids_before.include?(action.source_id)

    [ entity_ids_before - [ action.source_id ], nil ]
  end

  def projected_switch_ids
    return [ entity_ids_before, :source_absent ] unless entity_ids_before.include?(action.source_id)

    [ (entity_ids_before - [ action.source_id ]) | [ action.destination_id ], nil ]
  end

  def validate_source_neutrality
    return if action.add? || owner.is_a?(Budget)

    source_allocations = adapter.entity_allocations.select { |allocation| allocation.entity_id == action.source_id }
    non_neutral_reasons = source_allocations.flat_map { |allocation| AllocationMutations::EntityNeutrality.reasons(allocation) }.uniq
    return if non_neutral_reasons.empty?

    {
      reason_code: :entity_allocation_not_neutral,
      details: { entity_id: action.source_id, reasons: non_neutral_reasons }
    }
  end

  def validate_final_state(entity_ids_after)
    return unless owner.is_a?(Budget)

    final_state = AllocationMutations::BudgetFinalState.new(
      budget: owner,
      category_ids: adapter.category_ids,
      entity_ids: entity_ids_after
    )
    return if final_state.valid?

    {
      reason_code: :invalid_final_state,
      details: { errors: final_state.errors }
    }
  end

  def requested_entity_ids
    @requested_entity_ids ||= [ action.source_id, action.destination_id ].compact.uniq
  end

  def requested_entities
    @requested_entities ||= owner.user.entities.where(id: requested_entity_ids).index_by(&:id)
  end

  def entity_ids_before
    @entity_ids_before ||= adapter.entity_ids
  end

  def conflict(reason_code:, details: {})
    plan(AllocationMutations::Outcome.conflict(owner:, reason_code:, details:), entity_ids_after: entity_ids_before)
  end

  def noop(reason_code)
    plan(AllocationMutations::Outcome.noop(owner:, reason_code:), entity_ids_after: entity_ids_before)
  end

  def plan(outcome, entity_ids_after:)
    AllocationMutations::EntityPlan.new(
      owner:,
      action:,
      outcome:,
      entity_ids_before:,
      entity_ids_after:
    )
  end
end
