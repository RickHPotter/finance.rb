# frozen_string_literal: true

class Views::Budgets::MonthYearContainer < Views::Base
  attr_reader :search_term, :active_month_years,
              :category_id, :entity_id, :sort, :direction

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @active_month_years = index_context[:active_month_years]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @sort = index_context[:sort]
    @direction = index_context[:direction]
  end

  def view_template
    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params: { search_term:, sort:, direction:, budget: { category_id:, entity_id: } },
      path_lambda: ->(params) { month_year_budgets_path(params) }
    )
  end
end
