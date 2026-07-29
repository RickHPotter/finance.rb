# frozen_string_literal: true

class AllocationMutations::BatchPlanner
  attr_reader :actor, :context, :selection, :action

  def initialize(actor:, context:, action:, **options)
    @actor = actor
    @context = context
    @selection = AllocationMutations::OwnerSelection.new(
      actor:,
      context:,
      owner_type: options.fetch(:owner_type),
      owner_ids: options.fetch(:owner_ids),
      selected_row_count: options[:selected_row_count]
    )
    @action = action
    @owners = options[:owners]
  end

  def call
    AllocationMutations::Preview.new(
      actor:,
      context:,
      selection:,
      action:,
      plans: selected_owners.map { |owner| planner_class.new(owner:, action:).call }
    )
  end

  private

  def selected_owners
    return selection.owners if @owners.blank?

    records = Array(@owners).sort_by(&:id)
    raise ActiveRecord::RecordNotFound, "locked allocation owners do not match selection" unless records.map(&:id) == selection.owner_ids

    records
  end

  def planner_class
    return AllocationMutations::CategoryPlanner if action.allocation_type == :category
    return AllocationMutations::EntityPlanner if action.allocation_type == :entity

    raise ArgumentError, "unsupported allocation type"
  end
end
