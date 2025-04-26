# frozen_string_literal: true

class BudgetsController < ApplicationController
  include TabsConcern

  before_action :set_budget, only: %i[edit update destroy]

  def index
    build_index_context

    respond_to do |format|
      format.html do
        render Views::Budgets::Index.new(index_context: @index_context)
      end

      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :budget)
      end
    end
  end

  def month_year
    month_year     = search_budget_params[:month_year]
    year           = month_year[0..3].to_i
    month          = month_year[4..].to_i
    month_year_str = I18n.l(Date.new(year, month, 1), format: "%B %Y")

    budgets = Logic::Budgets.find_by_ref_month_year_by_params(current_user, month, year, budget_params)

    render Views::Budgets::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, budgets:)
  end

  def new
    @budget = current_user.budgets.new

    respond_to do |format|
      format.html { render Views::Budgets::New.new(current_user:, budget: @budget) }
      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :budget)
      end
    end
  end

  def create
    @budget = Logic::Budgets.create(budget_params)

    if @budget
      load_based_on_save
      build_index_context
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end

    respond_to(&:turbo_stream)
  end

  def edit
    respond_to do |format|
      format.html { render Views::Budgets::Edit.new(current_user:, budget: @budget) }
      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :budget)
      end
    end
  end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params)

    if @budget
      load_based_on_save
      build_index_context
      set_tabs(active_menu: :cash, active_sub_menu: :pix) if @budget.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @budget.destroy
    set_tabs(active_menu: :cash, active_sub_menu: :budget)
    build_index_context

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
    min_date = current_user.budgets.where(active: true).minimum("MAKE_DATE(year, month, 1)") || Time.zone.today
    max_date = current_user.budgets.where(active: true).maximum("MAKE_DATE(year, month, 1)") || Time.zone.today
    default_active_month_years = [ min_date.strftime("%Y%m").to_i ]
    years = @years || (min_date.year..max_date.year)
    default_year = @default_year || params[:default_year]&.to_i || [ max_date, Time.zone.today ].min.year
    active_month_years = @active_month_years || (params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years)

    category_id = [ budget_params[:category_id] ].flatten&.compact_blank
    entity_id = [ budget_params[:entity_id] ].flatten&.compact_blank
    search_term = search_budget_params[:search_term]

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      category_id:,
      entity_id:
    }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_budget
    @budget = current_user.budgets.find(params[:id])
  end

  def search_budget_params
    params.permit(:search_term, :month_year)
  end

  # Only allow a list of trusted parameters through.
  def budget_params
    return {} if params[:budget].blank?

    params.require(:budget).permit(
      :description, :value, :inclusive, :month, :year, :active, :user_id, :category_id, :entity_id,
      category_id: [], entity_id: [],
      budget_categories_attributes: %i[id category_id _destroy],
      budget_entities_attributes: %i[id entity_id _destroy]
    )
  end
end
