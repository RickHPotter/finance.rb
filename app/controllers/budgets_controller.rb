# frozen_string_literal: true

class BudgetsController < ApplicationController
  include TabsConcern

  before_action :set_budget, only: %i[edit update destroy]
  before_action :set_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def new
    @budget = Budget.new

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :budget) if params[:no_budget]
      end
    end
  end

  def create
    @budget = Logic::Budgets.create(budget_params)

    if @budget
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params)

    if @budget
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :pix) if @budget.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @budget.destroy
    load_based_on_save
    set_tabs(active_menu: :basic, active_sub_menu: :budget)

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    min_date = current_user.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = current_user.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    @years = (min_date.year..max_date.year)
    @default_year = @budget.year
    @active_month_years = [ Date.new(@budget.year, @budget.month, 1).strftime("%Y%m").to_i ]
    set_all_categories
    set_entities
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_budget
    @budget = Budget.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def budget_params
    ret_params = params.require(:budget)
    ret_params[:year], ret_params[:month] = ret_params[:month_year].split("-")
    ret_params[:value] = ret_params[:value].to_i.abs * -1 if ret_params[:value].present?

    ret_params.permit(:description, :value, :inclusive, :month, :year, :active, :user_id,
                      budget_categories_attributes: %i[id category_id _destroy],
                      budget_entities_attributes: %i[id entity_id _destroy])
  end
end
