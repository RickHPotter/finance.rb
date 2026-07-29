# frozen_string_literal: true

class AllocationMutations::IndependenceClassifier
  INSEPARABLE_REASON_CODES = %i[
    structural_category_allocation
    structural_entity_allocation
    subscription_owned_category
    subscription_owned_entity
  ].freeze

  attr_reader :plans

  def initialize(plans:)
    @plans = Array(plans)
  end

  def eligible_only_available?
    plans.any?(&:eligible?) &&
      plans.any?(&:conflict?) &&
      !conflict_reason_codes.intersect?(INSEPARABLE_REASON_CODES)
  end

  private

  def conflict_reason_codes
    plans.filter_map { |plan| plan.outcome.reason_code if plan.conflict? }.uniq
  end
end
