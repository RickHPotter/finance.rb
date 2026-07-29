# frozen_string_literal: true

AllocationMutations::EntityPlan = Data.define(:owner, :action, :outcome, :entity_ids_before, :entity_ids_after) do
  def initialize(owner:, action:, outcome:, entity_ids_before:, entity_ids_after:)
    raise ArgumentError, "entity action required" unless action.is_a?(AllocationMutations::Action) && action.allocation_type == :entity
    raise ArgumentError, "allocation outcome required" unless outcome.is_a?(AllocationMutations::Outcome)

    super(
      owner:,
      action:,
      outcome:,
      entity_ids_before: normalize_ids(entity_ids_before),
      entity_ids_after: normalize_ids(entity_ids_after)
    )
  end

  def eligible? = outcome.eligible?
  def noop? = outcome.noop?
  def conflict? = outcome.conflict?

  private

  def normalize_ids(values)
    Array(values).map { |value| Integer(value) }.uniq.sort.freeze
  end
end
