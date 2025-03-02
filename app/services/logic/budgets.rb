# frozen_string_literal: true

module Logic
  class Budgets
    def self.create(budget_params)
      budget = Budget.new(budget_params)
      _handle_creation(budget)
    end

    def self.update(budget, budget_params)
      budget.assign_attributes(budget_params)
      _handle_creation(budget)
    end

    def self._handle_creation(budget)
      budget.save
      budget
    end

    def self.find_by_ref_month_year(user, month, year, raw_conditions)
      return [] if raw_conditions[:cash_installments_count]&.exclude?(1)

      search_term_condition = "description ILIKE '%#{raw_conditions[:search_term]}%'" if raw_conditions[:search_term].present?

      conditions = {
        price: raw_conditions[:price],
        **raw_conditions[:associations]
      }.compact_blank

      fetch_budgets(user, month, year, conditions, search_term_condition)
    end

    def self.fetch_budgets(user, month, year, conditions, search_term_condition)
      past_installments = user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month <= ?)", year, year, month).sum(:price)
      past_budgets      = user.budgets.where("year < ? OR (year = ? AND month < ?)", year, year, month).sum(:remaining_value)

      initial_balance = past_installments + past_budgets

      user.budgets
          .where(conditions.merge(month:, year:))
          .where(search_term_condition)
          .includes(:categories, :entities)
          .select("budgets.*, #{initial_balance} + remaining_value AS balance")
          .order(:id)
    end
  end
end
