# frozen_string_literal: true

class AllocationMutations::IndependenceClassifier
  INSEPARABLE_REASON_CODES = %i[
    structural_category_allocation
    structural_entity_allocation
    subscription_owned_category
    subscription_owned_entity
  ].freeze

  attr_reader :plans, :dependency_keys

  def initialize(plans:, dependency_keys: nil)
    @plans = Array(plans)
    @dependency_keys = dependency_keys
  end

  def eligible_only_available?
    return false unless eligible_plans.any? && conflict_plans.any?
    return graph_independent? if dependency_keys

    !conflict_reason_codes.intersect?(INSEPARABLE_REASON_CODES)
  end

  private

  def graph_independent?
    conflict_plans.none? do |conflict_plan|
      eligible_plans.any? { |eligible_plan| keys_for(eligible_plan).intersect?(keys_for(conflict_plan)) }
    end
  end

  def keys_for(plan)
    Array(dependency_keys.call(plan)).to_set
  end

  def eligible_plans
    @eligible_plans ||= plans.select(&:eligible?)
  end

  def conflict_plans
    @conflict_plans ||= plans.select(&:conflict?)
  end

  def conflict_reason_codes
    conflict_plans.map { |plan| plan.outcome.reason_code }.uniq
  end
end
