# frozen_string_literal: true

# Shared functionality for models that can have budgets.
module Budgetable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :should_update, :should_update_all

    # @callbacks ..............................................................
    after_create :attach_budget
    before_update :flag_for_update
    after_update :update_budgets
    after_destroy :update_budgets
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def attach_budget
    if is_a?(CashTransaction)
      cash_installments.where(month:, year:).sum(:price)
    else
      card_installments.where(month:, year:).sum(:price)
    end => installments_price

    relevant_budgets.each do |budget|
      budget.update(remaining_value: budget.remaining_value - installments_price)
    end
  end

  def flag_for_update
    self.should_update = true if price_changed? || month_changed? || year_changed?

    unnecessary_changes = %i[description comment paid starting_price advance_cash_transaction_id user_id user_card_id user_bank_account_id]
    self.should_update_all = changes.without(*unnecessary_changes).empty?
  end

  def update_budgets
    relevant_budgets.each do |budget|
      budget.set_remaining_value
      budget.save
      budget.touch
    end
  end

  def relevant_budgets
    budgets = user.budgets.where(month:, year:)
    return budgets if should_update_all || destroyed?

    budgets.select do |budget|
      if budget.inclusive
        budget.categories.intersect?(categories) && budget.entities.intersect?(entities)
      else
        budget.categories.intersect?(categories) || budget.entities.intersect?(entities)
      end
    end
  end
end
