# frozen_string_literal: true

class Views::Investments::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :user_bank_account_id,
              :investment_type_id,
              :active_month_years,
              :url_lambda

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @investment_type_id = index_context[:investment_type_id]
    @active_month_years = index_context[:active_month_years]
  end

  def view_template
    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params: {
        investment: { user_bank_account_id:, investment_type_id: }.compact_blank,
        search_term:
      },
      path_lambda: ->(params) { month_year_investments_path(params) }
    )
  end
end
