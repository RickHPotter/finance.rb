# frozen_string_literal: true

class Views::CashTransactions::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :category_ids, :entity_ids,
              :from_ct_price, :to_ct_price,
              :from_price, :to_price,
              :from_installments_count, :to_installments_count,
              :user_bank_account_id, :active_month_years

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @category_ids = index_context[:category_ids]
    @entity_ids = index_context[:entity_ids]
    @from_ct_price = index_context[:from_ct_price]
    @to_ct_price = index_context[:to_ct_price]
    @from_price = index_context[:from_price]
    @to_price = index_context[:to_price]
    @from_installments_count = index_context[:from_installments_count]
    @to_installments_count = index_context[:to_installments_count]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @active_month_years = index_context[:active_month_years]
  end

  def view_template
    turbo_frame_tag :month_year_container do
      custom_params = {
        user_bank_account_id:,
        search_term:,
        category_ids:,
        entity_ids:,
        from_ct_price:,
        to_ct_price:,
        from_price:,
        to_price:,
        from_installments_count:,
        to_installments_count:
      }

      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: month_year_cash_transactions_path(custom_params.merge(month_year:))
      end
    end
  end
end
