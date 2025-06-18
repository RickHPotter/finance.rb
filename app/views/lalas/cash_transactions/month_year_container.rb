# frozen_string_literal: true

class Views::Lalas::CashTransactions::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :category_id, :entity_id,
              :user_bank_account_id, :active_month_years,
              :skip_budgets, :force_mobile

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @active_month_years = index_context[:active_month_years]
    @skip_budgets = index_context[:skip_budgets]
    @force_mobile = index_context[:force_mobile]
  end

  def view_template
    turbo_frame_tag :month_year_container do
      custom_params = {
        cash_transaction: {
          user_bank_account_id:,
          category_id:,
          entity_id:
        },
        search_term:,
        skip_budgets:,
        force_mobile:
      }

      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: cash_transactions_month_year_lalas_path(custom_params.merge(month_year:))
      end
    end
  end
end
