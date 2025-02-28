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
    @card_transaction = Logic::CardTransactions.create_from(budget: @budget) if @budget.valid?

    if @card_transaction
      set_budgets
      set_tabs(active_menu: :basic, active_sub_menu: :card_transaction)
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params)
    @card_transaction = Logic::CardTransactions.create_from(budget: @budget) if @budget.valid?

    if @card_transaction
      set_budgets
      set_tabs(active_menu: :basic, active_sub_menu: :card_transaction) if @budget.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @budget.destroy
    set_tabs(active_menu: :basic, active_sub_menu: :budget)

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_budget
    @budget = Budget.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def budget_params
    ret_params = params.require(:budget)
    ret_params[:month], ret_params[:year] = ret_params[:month_year].split("-")

    ret_params.permit(:value, :inclusive, :month, :year, :active, :user_id,
                      budget_categories_attributes: %i[id category_id _destroy],
                      budget_entities_attributes: %i[id entity_id _destroy])
  end
end
