# frozen_string_literal: true

AllocationMutations::CategoryPlan = Data.define(:owner, :action, :outcome, :category_ids_before, :category_ids_after) do
  def initialize(owner:, action:, outcome:, category_ids_before:, category_ids_after:)
    raise ArgumentError, "category action required" unless action.is_a?(AllocationMutations::Action) && action.allocation_type == :category
    raise ArgumentError, "allocation outcome required" unless outcome.is_a?(AllocationMutations::Outcome)

    super(
      owner:,
      action:,
      outcome:,
      category_ids_before: normalize_ids(category_ids_before),
      category_ids_after: normalize_ids(category_ids_after)
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
