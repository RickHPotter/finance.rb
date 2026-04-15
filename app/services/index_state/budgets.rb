# frozen_string_literal: true

module IndexState
  class Budgets < Base
    DEFAULT_SORT = "default"
    DEFAULT_DIRECTION = "asc"
    FILTER_KEYS = %i[search_term].freeze
    ARRAY_FILTER_KEYS = %i[category_id entity_id].freeze

    attr_reader :budget_filters, :search_filters, :years_override, :default_year_override, :active_month_years_override

    def initialize(current_user:, current_context:, params:, **options)
      super(current_user:, current_context:, params:)
      @budget_filters = options[:budget_filters] || {}
      @search_filters = options[:search_filters] || {}
      @years_override = options[:years]
      @default_year_override = options[:default_year]
      @active_month_years_override = options[:active_month_years]
    end

    def to_h
      state = resolved_state

      base_context(state).merge(
        filter_context,
        sort_context,
        count_context
      )
    end

    private

    def base_context(state)
      {
        current_user:,
        years: state[:years],
        default_year: state[:default_year],
        active_month_years: state[:active_month_years]
      }
    end

    def resolved_state
      min_date, max_date = budget_date_bounds

      {
        years: years_override || (min_date.year..max_date.year),
        default_year: default_year_override || params[:default_year]&.to_i || min_date.year,
        active_month_years: active_month_years_override || parse_active_month_years(params[:active_month_years]).presence || default_active_month_years_for(min_date)
      }
    end

    def filter_context
      values_from(search_filters, *FILTER_KEYS).merge(
        category_id: compact_array(budget_filters[:category_id]),
        entity_id: compact_array(budget_filters[:entity_id])
      )
    end

    def sort_context
      {
        sort: DEFAULT_SORT,
        direction: DEFAULT_DIRECTION
      }
    end

    def count_context
      {
        count_by_month_year: Logic::Budgets.find_count_based_on_search(current_context, budget_filters, search_filters)
      }
    end

    def budget_date_bounds
      today = Time.zone.today

      [
        current_context.budgets.active.minimum("MAKE_DATE(budgets.year, budgets.month, 1)") || today,
        current_context.budgets.active.maximum("MAKE_DATE(budgets.year, budgets.month, 1)") || today
      ]
    end

    def default_active_month_years_for(min_date)
      [ min_date.strftime("%Y%m").to_i, (min_date + 1.month).strftime("%Y%m").to_i ]
    end
  end
end
