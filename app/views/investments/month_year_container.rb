# frozen_string_literal: true

class Views::Investments::MonthYearContainer < Views::Base
  attr_reader :search_term,
              :user_bank_account_ids,
              :active_month_years,
              :url_lambda

  def initialize(index_context: {}, url_lambda: ->(args = {}) { month_year_card_transactions_path(args) })
    @search_term = index_context[:search_term]
    @user_bank_account_ids = index_context[:user_bank_account_ids]
    @active_month_years = index_context[:active_month_years]
    @url_lambda = url_lambda
  end

  def view_template
    turbo_frame_tag :month_year_container do
      custom_params = { search_term:, user_bank_account_ids: }

      active_month_years.sort.each do |month_year|
        turbo_frame_tag "month_year_container_#{month_year}", src: url_lambda.call(custom_params.merge(month_year:))
      end
    end
  end
end
