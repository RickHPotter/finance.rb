# frozen_string_literal: true

# Shared functionality for models that can have budgets.
module Budgetable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :should_update, :should_update_all

    # @callbacks ..............................................................
    before_update :flag_for_update
    after_commit :update_relevant_budgets
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def flag_for_update
    unnecessary_changes = %i[description comment paid starting_price advance_cash_transaction_id user_id user_card_id user_bank_account_id]
    self.should_update_all = changes.without(*unnecessary_changes).empty?
  end

  def update_relevant_budgets
    budgets = user.budgets.where(month:, year:)
    if should_update_all || destroyed?
      budgets.each(&:save)
      return
    end

    categories = category_transactions.map(&:category)
    entities = entity_transactions.map(&:entity)

    relevant_budgets = budgets.select do |budget|
      if budget.inclusive
        budget.categories.intersect?(categories) && budget.entities.intersect?(entities)
      else
        budget.categories.intersect?(categories) || budget.entities.intersect?(entities)
      end
    end

    relevant_budgets.each(&:save)
  end
end
