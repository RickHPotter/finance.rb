# frozen_string_literal: true

# Controller for Balances Chart
class BalancesController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: :index

  def index
    respond_to do |format|
      format.html do
        render Views::Balances::Index.new(mobile: @mobile)
      end

      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :balance)
      end
    end
  end

  def cash_balance_json
    result = Logic::Finder::CashBalanceJson.new(user: current_user).call
    render json: result
  end

  def transaction_balance_json
    month_year_one = params[:month_year_one]&.to_date
    month_year_two = params[:month_year_two]&.to_date

    result = Logic::Finder::TransactionBalanceJson.new(user: current_user, month_year_one:, month_year_two:).call
    render json: result
  end
end
