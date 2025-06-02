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

  def budgets
    month_years = []
    month_years << card_installments.map { |i| i.slice(:month, :year) } if respond_to?(:card_installments)
    month_years << cash_installments.map { |i| i.slice(:month, :year) } if respond_to?(:cash_installments)

    user.budgets.where(month_years.flatten)
  end

  def update_relevant_budgets
    if should_update_all || destroyed?
      user.budgets.each(&:save)
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
