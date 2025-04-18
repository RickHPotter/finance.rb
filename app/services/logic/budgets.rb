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
      return [] if raw_conditions[:skip_budgets]

      search_term_condition = "description ILIKE '%#{raw_conditions[:search_term]}%'" if raw_conditions[:search_term].present?

      conditions = {
        price: raw_conditions[:price],
        **raw_conditions[:associations]
      }.compact_blank

      fetch_budgets(user, month, year, conditions, search_term_condition)
    end

    def self.fetch_budgets(user, month, year, conditions, search_term_condition)
      user.budgets
          .where(conditions.merge(month:, year:))
          .where(search_term_condition)
          .includes(:categories, :entities)
          .order(:id)
    end
  end
end
