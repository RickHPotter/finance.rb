# frozen_string_literal: true

class AllocationMutations::EntityMutator
  class IneligiblePlan < ArgumentError; end
  class StalePlan < StandardError; end

  NEUTRAL_ATTRIBUTES = {
    is_payer: false,
    price: 0,
    price_to_be_returned: 0,
    loan_return_percentage: 0,
    status: :finished
  }.freeze

  attr_reader :plan, :owner, :action, :adapter

  def initialize(plan:)
    @plan = plan
    @owner = plan.owner
    @action = plan.action
    @adapter = AllocationMutations::OwnerAdapter.for(owner)
  end

  def call
    raise IneligiblePlan, "entity mutation requires an eligible plan" unless plan.eligible?

    owner.transaction do
      validate_current_state!
      apply_operation
      prepare_owner_recalculation
      owner.save!
    end

    AllocationMutations::Impact.build(
      owner:,
      entity_ids_before: plan.entity_ids_before,
      entity_ids_after: plan.entity_ids_after
    )
  end

  private

  def validate_current_state!
    return if current_entity_ids == plan.entity_ids_before

    raise StalePlan, "entity allocations changed after planning"
  end

  def apply_operation
    if action.add?
      add_destination
    elsif action.remove?
      remove_source
    else
      remove_source
      add_destination
    end
  end

  def add_destination
    return if entity_allocations.any? { |allocation| allocation.entity_id == action.destination_id }

    attributes = { entity_id: action.destination_id }
    attributes.merge!(NEUTRAL_ATTRIBUTES) unless owner.is_a?(Budget)
    entity_allocations.build(attributes).save!
  end

  def remove_source
    entity_allocations.select { |allocation| allocation.entity_id == action.source_id }.each(&:destroy!)
  end

  def prepare_owner_recalculation
    owner.original_entities = plan.entity_ids_before if owner.respond_to?(:original_entities=)
    owner.recalculate_balance = nil if owner.is_a?(Budget)
  end

  def entity_allocations
    adapter.entity_allocations
  end

  def current_entity_ids
    entity_allocations.reorder(nil).pluck(:entity_id).uniq.sort
  end
end
