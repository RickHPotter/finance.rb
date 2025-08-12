# frozen_string_literal: true

class Views::Investments::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :user_bank_account_id,
              :active_month_years,
              :url_lambda

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @active_month_years = index_context[:active_month_years]
  end

  def view_template
    turbo_frame_tag :month_year_container do
      custom_params = {
        investment: { user_bank_account_id: }.compact_blank,
        search_term:
      }

      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: month_year_investments_path(custom_params.merge(month_year:))
      end
    end
  end
end
