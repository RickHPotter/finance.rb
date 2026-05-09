# frozen_string_literal: true

class Views::Lalas::CashTransactions::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :category_id, :entity_id,
              :user_bank_account_id, :paid, :pending, :active_month_years,
              :skip_budgets, :force_mobile, :external_route_params, :internal_route_params

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @paid = index_context[:paid]
    @pending = index_context[:pending]
    @active_month_years = index_context[:active_month_years]
    @skip_budgets = index_context[:skip_budgets]
    @force_mobile = index_context[:force_mobile]
    @external_route_params = index_context[:external_route_params]
    @internal_route_params = index_context[:internal_route_params]
  end

  def view_template
    custom_params = {
      cash_transaction: {
        user_bank_account_id:,
        category_id:,
        entity_id:
      },
      search_term:,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:
    }

    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params:,
      path_lambda: ->(params) { month_year_cash_transactions_path(params) }
    )
  end

  private

  def month_year_cash_transactions_path(params)
    return month_year_internal_cash_transactions_path(**internal_route_params, **params) if internal_route_params.present?
    return month_year_external_cash_transactions_path(**external_route_params, **params) if external_route_params.present?

    month_year_lalas_cash_transactions_path(params)
  end
end
