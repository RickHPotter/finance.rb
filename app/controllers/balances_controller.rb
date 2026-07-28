# frozen_string_literal: true

# Controller for Balances Chart
class BalancesController < ApplicationController
  include TabsConcern

  before_action :set_balance_tabs, only: %i[index monthly_analysis]

  def index
    render Views::Balances::Mobile.new(tab: balance_tab, month: balance_month)
  end

  def cash_balance_json
    result = Logic::Finder::CashBalanceJson.new(user: current_user, context: current_context).call
    render json: result
  end

  def current_balance_json
    result = Logic::Finder::CurrentBalanceJson.new(user: current_user, context: current_context).call
    render json: result
  end

  def monthly_analysis
    render Views::Balances::MonthlyAnalysis.new(month: balance_month)
  end

  def monthly_analysis_json
    result = Logic::Finder::MonthlyAnalysisJson.new(user: current_user, context: current_context, month: params[:month]).call
    render json: result
  rescue Logic::Finder::MonthlyAnalysisJson::InvalidMonthError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def balance_tab
    params[:tab].presence_in(%w[overview monthly_analysis]) || "overview"
  end

  def balance_month
    raw_month = params[:month].presence || Time.zone.today.strftime("%Y-%m")
    Date.strptime(raw_month, "%Y-%m")
    raw_month
  rescue Date::Error
    Time.zone.today.strftime("%Y-%m")
  end

  def set_balance_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :balance)
  end
end
