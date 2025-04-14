# frozen_string_literal: true

class InvestmentsController < ApplicationController
  include TabsConcern

  before_action :set_investment, only: %i[edit update destroy]

  def index
    build_index_context

    respond_to do |format|
      format.html do
        render Views::Investments::Index.new(index_context: @index_context)
      end
    end
  end

  def month_year
    month_year = params[:month_year]
    month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

    investments = Logic::Investments.find_ref_month_year_by_params(current_user, params.to_unsafe_h)

    render Views::Investments::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, investments:)
  end

  def new
    @investment = Investment.new

    respond_to do |format|
      format.html { render Views::Investments::New.new(current_user:, investment: @investment) }
      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :investment)
      end
    end
  end

  def create
    @investment = Logic::Investments.create(investment_params)

    if @investment
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :investment)
    end

    respond_to(&:turbo_stream)
  end

  def edit
    respond_to do |format|
      format.html { render Views::Investments::Edit.new(current_user:, investment: @investment) }
      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :investment)
      end
    end
  end

  def update
    @investment = Logic::Investments.update(@investment, investment_params)

    if @investment
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :investment)
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @investment.destroy
    set_tabs(active_menu: :basic, active_sub_menu: :investment)
    build_index_context

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    min_date = current_user.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = current_user.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    years = (min_date.year..max_date.year)
    default_year = @investment.year
    active_month_years = [ Date.new(@investment.year, @investment.month, 1).strftime("%Y%m").to_i ]

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      user_bank_account_ids: [ @investment.user_bank_account_id ]
    }
  end

  def build_index_context # rubocop:disable Metrics/AbcSize
    min_date = Investment.minimum("MAKE_DATE(year, month, 1)") || Date.current
    max_date = Investment.maximum("MAKE_DATE(year, month, 1)") || Date.current
    default_active_month_years = [ [ max_date, Date.current ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)
    default_year = params[:default_year]&.to_i || [ max_date, Date.current ].min.year
    active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years

    search_term = search_investment_params[:search_term]
    user_bank_account_ids = search_investment_params[:user_bank_account_ids] || [ params[:user_bank_account_ids] ].compact_blank

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      user_bank_account_ids:
    }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_investment
    @investment = Investment.find(params[:id])
  end

  def search_investment_params
    return {} if params[:investment].blank?

    params.require(:investment).permit(%i[search_term], user_bank_account_ids: [])
  end

  # Only allow a list of trusted parameters through.
  def investment_params
    ret_params = params.require(:investment)
    ret_params[:price] = ret_params[:price].to_i if ret_params[:price].present?

    ret_params.permit(:description, :price, :date, :month, :year, :user_id, :user_bank_account_id)
  end
end
