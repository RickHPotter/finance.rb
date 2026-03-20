# frozen_string_literal: true

class InvestmentsController < ApplicationController
  include TabsConcern

  before_action :set_investment, only: %i[edit update destroy]
  before_action :set_investment_tabs

  def index
    build_index_context

    respond_to do |format|
      format.html { render Views::Investments::Index.new(index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def month_year
    month_year = search_investment_params[:month_year]
    month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

    investments = Logic::Investments.find_ref_month_year_by_params(current_user, investment_params, search_investment_params)

    render Views::Investments::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, investments:, current_user:)
  end

  def new
    user_bank_account_id = investment_params[:user_bank_account_id]
    investment_type_id = investment_params[:investment_type_id]

    @investment = current_user.investments.new(user_bank_account_id:, investment_type_id:)

    if user_bank_account_id && investment_type_id
      investments = @investment.user_bank_account.investments.where(investment_type_id:)
      @investment.date = investments.maximum(:date)
    end

    @investment.date = @investment.date + 1.day if params[:next_day]
    @investment.date ||= Time.zone.now

    respond_to do |format|
      format.html { render Views::Investments::New.new(current_user:, investment: @investment) }
      format.turbo_stream
    end
  end

  def create
    @investment = Logic::Investments.create(investment_params)

    load_based_on_save if @investment

    respond_to(&:turbo_stream)
  end

  def edit
    respond_to do |format|
      format.html { render Views::Investments::Edit.new(current_user:, investment: @investment) }
      format.turbo_stream
    end
  end

  def update
    @investment = Logic::Investments.update(@investment, investment_params)

    load_based_on_save if @investment

    respond_to(&:turbo_stream)
  end

  def destroy
    @investment.destroy
    build_index_context

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    min_date = current_user.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    max_date = current_user.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    years = (min_date.year..max_date.year)
    default_year = @investment.year
    active_month_years = [ Date.new(@investment.year, @investment.month, 1).strftime("%Y%m").to_i ]

    count_by_month_year = Logic::Investments.find_count_based_on_search(current_user, investment_params, search_investment_params)

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      user_bank_account_id: [ @investment.user_bank_account_id ],
      investment_type_id: [ @investment.investment_type_id ].compact_blank,
      count_by_month_year:
    }
  end

  def build_index_context # rubocop:disable Metrics/AbcSize
    min_date = current_user.investments.minimum("MAKE_DATE(year, month, 1)") || Time.zone.today
    max_date = current_user.investments.maximum("MAKE_DATE(year, month, 1)") || Time.zone.today
    default_active_month_years = [ [ max_date, Time.zone.today ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)
    default_year = params[:default_year]&.to_i || [ max_date, Time.zone.today ].min.year
    active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years

    search_term = search_investment_params[:search_term]
    user_bank_account_id = [ investment_params[:user_bank_account_id] ].flatten&.compact_blank
    investment_type_id = [ investment_params[:investment_type_id] ].flatten&.compact_blank

    count_by_month_year = Logic::Investments.find_count_based_on_search(current_user, investment_params, search_investment_params)

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      user_bank_account_id:,
      investment_type_id:,
      count_by_month_year:
    }
  end

  private

  def set_investment_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :investment)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_investment
    @investment = current_user.investments.find(params[:id])
  end

  def search_investment_params
    params.permit(%i[search_term month_year])
  end

  # Only allow a list of trusted parameters through.
  def investment_params
    return {} if params[:investment].blank?

    ret_params = params.require(:investment)
    ret_params[:price] = ret_params[:price].to_i if ret_params[:price].present?

    ret_params.permit(
      :description, :price, :date, :month, :year, :user_id, :user_bank_account_id, :investment_type_id,
      user_bank_account_id: [], investment_type_id: []
    )
  end
end
