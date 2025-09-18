# frozen_string_literal: true

# Shared functionality for models that can have budgets.
module Budgetable
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    after_save :update_relevant_budgets
    after_destroy :update_relevant_budgets
  end

  def budgets
    relevant_installments = [ *installments, *original_installments ]

    month_years = relevant_installments.map { |i| i.slice(:month, :year) }
    return Budget.none if month_years.empty?

    conditions = month_years.map { "(budgets.month = ? AND budgets.year = ?)" }.join(" OR ")
    values = month_years.flat_map { |h| [ h[:month], h[:year] ] }

    user.budgets.where(conditions, *values)
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def should_update_none?
    self.original_categories   ||= []
    self.original_entities     ||= []
    self.original_installments ||= []

    no_breaking_changes     = changes.slice(%i[date month year price]).none?
    no_categories_changed   = original_categories   == category_transactions.pluck(:category_id).sort
    no_entities_changed     = original_entities     == entity_transactions.pluck(:entity_id).sort
    no_installments_changed = original_installments == installments.order(:number).map { |i| i.slice(:number, :year, :month, :price) }

    no_breaking_changes && no_categories_changed && no_entities_changed && no_installments_changed
  end

  def update_relevant_budgets
    return if persisted? && should_update_none?

    relevant_categories = user.categories.where(id: original_categories + category_transactions.map(&:category_id))
    relevant_entities = user.entities.where(id: original_entities + entity_transactions.map(&:entity_id))

    relevant_budgets = budgets.select do |budget|
      if budget.inclusive
        budget.categories.intersect?(relevant_categories) && budget.entities.intersect?(relevant_entities)
      else
        budget.categories.intersect?(relevant_categories) || budget.entities.intersect?(relevant_entities)
      end
    end

    relevant_budgets.each do |budget|
      budget.update(recalculate_balance: false)
    end
  end
end
