# frozen_string_literal: true

class Views::Investments::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :investment_id,
              :user_bank_account_id,
              :investment_type_id,
              :piggy_bank_return_cash_transaction_id,
              :active_month_years,
              :url_lambda,
              :return_to

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @investment_id = index_context[:id]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @investment_type_id = index_context[:investment_type_id]
    @piggy_bank_return_cash_transaction_id = index_context[:piggy_bank_return_cash_transaction_id]
    @active_month_years = index_context[:active_month_years]
    @return_to = index_context[:return_to]
  end

  def view_template
    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params: {
        investment: {
          id: investment_id,
          user_bank_account_id:,
          investment_type_id:,
          piggy_bank_return_cash_transaction_id:
        }.compact_blank,
        search_term:,
        return_to:
      },
      path_lambda: ->(params) { month_year_investments_path(params) }
    )
  end
end
