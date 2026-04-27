# frozen_string_literal: true

class Views::CashTransactions::MonthYearContainer < Views::Base
  attr_reader :search_term, :cash_installment_ids,
              :category_id, :entity_id,
              :from_ct_price, :to_ct_price,
              :from_price, :to_price,
              :from_installments_count, :to_installments_count,
              :exchange_bound_type,
              :from_installments_number, :to_installments_number,
              :from_date, :to_date,
              :paid, :pending, :paid_state,
              :user_bank_account_id, :active_month_years, :default_year,
              :skip_budgets, :sort, :direction, :force_mobile

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @cash_installment_ids = index_context[:cash_installment_ids]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @from_ct_price = index_context[:from_ct_price]
    @to_ct_price = index_context[:to_ct_price]
    @from_price = index_context[:from_price]
    @to_price = index_context[:to_price]
    @from_installments_count = index_context[:from_installments_count]
    @to_installments_count = index_context[:to_installments_count]
    @exchange_bound_type = index_context[:exchange_bound_type]
    @from_installments_number = index_context[:from_installments_number]
    @to_installments_number = index_context[:to_installments_number]
    @from_date = index_context[:from_date]
    @to_date = index_context[:to_date]
    @paid = index_context[:paid]
    @pending = index_context[:pending]
    @paid_state = index_context[:paid_state]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @active_month_years = index_context[:active_month_years]
    @default_year = index_context[:default_year]
    @skip_budgets = index_context[:skip_budgets]
    @sort = index_context[:sort]
    @direction = index_context[:direction]
    @force_mobile = index_context[:force_mobile]
  end

  def view_template
    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params: {
        cash_transaction: {
          cash_installment_ids:,
          user_bank_account_id:,
          category_id:,
          entity_id:
        },
        search_term:,
        from_ct_price:,
        to_ct_price:,
        from_price:,
        to_price:,
        from_installments_count:,
        to_installments_count:,
        exchange_bound_type:,
        from_installments_number:,
        to_installments_number:,
        from_date:,
        to_date:,
        paid:,
        pending:,
        paid_state:,
        default_year:,
        active_month_years: active_month_years.to_json,
        skip_budgets:,
        sort:,
        direction:,
        force_mobile:
      },
      path_lambda: ->(params) { month_year_cash_transactions_path(params) }
    )
  end
end
