# frozen_string_literal: true

class AllocationMutations::CategoryMutator
  class IneligiblePlan < ArgumentError; end
  class StalePlan < StandardError; end

  attr_reader :plan, :owner, :action, :adapter

  def initialize(plan:)
    @plan = plan
    @owner = plan.owner
    @action = plan.action
    @adapter = AllocationMutations::OwnerAdapter.for(owner)
  end

  def call
    raise IneligiblePlan, "category mutation requires an eligible plan" unless plan.eligible?

    owner.transaction do
      validate_current_state!
      apply_operation
      prepare_owner_recalculation
      owner.save!
    end

    AllocationMutations::Impact.build(
      owner:,
      category_ids_before: plan.category_ids_before,
      category_ids_after: plan.category_ids_after
    )
  end

  private

  def validate_current_state!
    return if current_category_ids == plan.category_ids_before

    raise StalePlan, "category allocations changed after planning"
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
    return if category_allocations.any? { |allocation| allocation.category_id == action.destination_id }

    category_allocations.build(category_id: action.destination_id).save!
  end

  def remove_source
    category_allocations.select { |allocation| allocation.category_id == action.source_id }.each(&:destroy!)
  end

  def prepare_owner_recalculation
    owner.original_categories = plan.category_ids_before if owner.respond_to?(:original_categories=)
    owner.recalculate_balance = true if owner.is_a?(Budget)
  end

  def category_allocations
    adapter.category_allocations
  end

  def current_category_ids
    category_allocations.reorder(nil).pluck(:category_id).uniq.sort
  end
end
