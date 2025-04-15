# frozen_string_literal: true

class Views::Budgets::MonthYearContainer < Views::Base
  attr_reader :search_term, :active_month_years,
              :category_id, :entity_id

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @active_month_years = index_context[:active_month_years]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
  end

  def view_template
    turbo_frame_tag :month_year_container do
      custom_params = { search_term:, category_id:, entity_id: }

      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: month_year_budgets_path(custom_params.merge(month_year:))
      end
    end
  end
end
