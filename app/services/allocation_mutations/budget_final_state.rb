# frozen_string_literal: true

class AllocationMutations::BudgetFinalState
  attr_reader :budget, :category_ids, :entity_ids

  def initialize(budget:, category_ids:, entity_ids:)
    @budget = budget
    @category_ids = normalize_ids(category_ids)
    @entity_ids = normalize_ids(entity_ids)
  end

  def errors
    return [ I18n.t("activerecord.errors.models.budget.missing_categories_or_entities") ] if category_ids.empty? && entity_ids.empty?

    candidate.valid?
    candidate.errors.full_messages
  end

  def valid?
    errors.empty?
  end

  private

  def candidate
    @candidate ||= Budget.new(budget.attributes.except("created_at", "updated_at")).tap do |record|
      record.budget_categories.load
      record.budget_entities.load
      category_ids.each { |category_id| record.budget_categories.build(category_id:) }
      entity_ids.each { |entity_id| record.budget_entities.build(entity_id:) }
      record.id = budget.id
    end
  end

  def normalize_ids(values)
    Array(values).map { |value| Integer(value) }.uniq.sort.freeze
  end
end
