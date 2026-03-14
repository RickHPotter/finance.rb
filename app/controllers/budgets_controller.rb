# frozen_string_literal: true

class BudgetsController < ApplicationController
  include TabsConcern

  before_action :set_budget, only: %i[edit update destroy]
  before_action :set_budget_tabs

  def index
    build_index_context

    respond_to do |format|
      format.html { render Views::Budgets::Index.new(index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def month_year
    month_year     = search_budget_params[:month_year]
    year           = month_year[0..3].to_i
    month          = month_year[4..].to_i
    month_year_str = I18n.l(Date.new(year, month, 1), format: "%B %Y")

    budgets = Logic::Budgets.find_by_ref_month_year_by_params(current_user, month, year, budget_params.merge(search_budget_params.slice(:search_term)))

    render Views::Budgets::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, budgets:)
  end

  def new
    @budget = current_user.budgets.new

    respond_to do |format|
      format.html { render Views::Budgets::New.new(current_user:, budget: @budget) }
      format.turbo_stream
    end
  end

  def create
    @budget = Logic::Budgets.create(budget_params, multiple_budget_params)

    handle_save
  end

  def edit
    respond_to do |format|
      format.html { render Views::Budgets::Edit.new(current_user:, budget: @budget) }
      format.turbo_stream
    end
  end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params)

    handle_save
  end

  def destroy
    @budget.destroy
    build_index_context

    respond_to(&:turbo_stream)
  end

  def handle_save
    if @budget.valid?
      load_based_on_save
      build_index_context
      set_tabs(active_menu: :cash, active_sub_menu: :pix) if @budget.active?
    end

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    min_date = current_user.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    max_date = current_user.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    @years = (min_date.year..max_date.year)
    @default_year = @budget.year
    @active_month_years = [ Date.new(@budget.year, @budget.month, 1).strftime("%Y%m").to_i ]
  end

  def build_index_context # rubocop:disable Metrics/AbcSize
    min_date = current_user.budgets.active.minimum("MAKE_DATE(budgets.year, budgets.month, 1)") || Time.zone.today
    max_date = current_user.budgets.active.maximum("MAKE_DATE(budgets.year, budgets.month, 1)") || Time.zone.today

    default_active_month_years = [ min_date.strftime("%Y%m").to_i, (min_date + 1.month).strftime("%Y%m").to_i ]
    years = @years || (min_date.year..max_date.year)
    default_year = @default_year || params[:default_year]&.to_i || min_date.year
    active_month_years = @active_month_years || (params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years)

    category_id = [ budget_params[:category_id] ].flatten&.compact_blank
    entity_id = [ budget_params[:entity_id] ].flatten&.compact_blank
    search_term = search_budget_params[:search_term]

    count_by_month_year = Logic::Budgets.find_count_based_on_search(current_user, budget_params, search_budget_params)

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      category_id:,
      entity_id:,
      count_by_month_year:
    }
  end

  private

  def set_budget_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :budget)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_budget
    @budget = current_user.budgets.find(params[:id])
  end

  def search_budget_params
    params.permit(:search_term, :month_year)
  end

  def multiple_budget_params
    params.permit(month_years: [])
  end

  # Only allow a list of trusted parameters through.
  def budget_params
    return {} if params[:budget].blank?

    ret_params = params.require(:budget)
    ret_params[:year], ret_params[:month] = ret_params[:month_year].split("-") if ret_params[:month_year].present?

    ret_params.permit(
      :description, :value, :inclusive, :first_installment_only, :month, :year, :active, :user_id, :category_id, :entity_id,
      category_id: [], entity_id: [],
      budget_categories_attributes: %i[id category_id _destroy],
      budget_entities_attributes: %i[id entity_id _destroy]
    )
  end
end
