# frozen_string_literal: true

module Logic
  class Budgets
    def self.create(budget_params, multiple_budget_params)
      multiple_references = multiple_budget_params[:month_years]
      if multiple_references.nil?
        budget = Budget.new(budget_params)
        _handle_creation(budget)
      else
        budgets = multiple_references.map do |month_year|
          date = month_year.to_date
          Budget.create(budget_params.merge(year: date.year, month: date.month))
        end

        budgets.first
      end
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

    def self.find_by_ref_month_year_by_params(user, month, year, params)
      raw_conditions = build_conditions_from_params(params)
      find_by_ref_month_year(user, month, year, raw_conditions)
    end

    def self.fetch_budgets(user, month, year, conditions, search_term_condition)
      user.budgets
          .where(conditions.merge(month:, year:))
          .where(search_term_condition)
          .includes(:categories, :entities)
          .order(:order_id)
    end

    def self.build_conditions_from_params(params)
      category_id = params.delete(:category_id).presence
      category_id = [ category_id ].flatten.compact_blank if category_id.present?
      entity_id   = params.delete(:entity_id).presence
      entity_id   = [ entity_id ].flatten.compact_blank if entity_id.present?

      {
        search_term: params["search_term"],
        associations: {
          categories: { id: category_id }.compact_blank,
          entities: { id: entity_id }.compact_blank
        }.compact_blank
      }.compact_blank
    end

    def self.find_count_based_on_search(user, budget_params, search_params)
      search_term = search_params.delete(:search_term) || ""
      raw_conditions = build_conditions_from_params(budget_params.is_a?(Hash) ? budget_params.dup : budget_params.to_unsafe_h)

      relation = user.budgets
                     .left_joins(:categories, :entities)
                     .where(raw_conditions[:associations])
                     .where("budgets.description ILIKE ?", "%#{search_term}%")

      relation = relation.distinct.select("budgets.id, budgets.month, budgets.year")

      relation.group_by { |record| Date.new(record.year, record.month, 1).strftime("%Y%m").to_i }
    end
  end
end
