# frozen_string_literal: true

# Controller for Balances Chart
class BalancesController < ApplicationController
  include TabsConcern

  before_action :set_balance_tabs, only: %i[index legacy]

  def index
    render Views::Balances::Mobile.new
  end

  def legacy
    respond_to do |format|
      format.html { render Views::Balances::Index.new(mobile: @mobile) }
      format.turbo_stream
    end
  end

  def cash_balance_json
    result = Logic::Finder::CashBalanceJson.new(user: current_user, context: current_context).call
    render json: result
  end

  def current_balance_json
    result = Logic::Finder::CurrentBalanceJson.new(user: current_user, context: current_context).call
    render json: result
  end

  def transaction_balance_json
    month_year_one = params[:month_year_one]&.to_date
    month_year_two = params[:month_year_two]&.to_date

    result = Logic::Finder::TransactionBalanceJson.new(user: current_user, context: current_context, month_year_one:, month_year_two:).call
    render json: result
  end

  private

  def set_balance_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :balance)
  end
end
