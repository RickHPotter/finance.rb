# frozen_string_literal: true

class InvestmentsController < ApplicationController
  include TabsConcern

  before_action :set_investment, only: %i[edit update destroy]
  before_action :set_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @investments = Investment.all
    render Views::Investments::Index.new(current_user:, investments: @investments)
  end

  def new
    @investment = Investment.new

    respond_to do |format|
      format.html { render Views::Investments::New.new(current_user:, investment: @investment) }
      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :investment) if params[:no_investment]
      end
    end
  end

  def create
    @investment = Logic::Investments.create(investment_params)

    if @investment
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    @investment = Logic::Investments.update(@investment, investment_params)

    if @investment
      load_based_on_save
      set_tabs(active_menu: :cash, active_sub_menu: :pix) if @investment.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @investment.destroy
    load_based_on_save
    set_tabs(active_menu: :basic, active_sub_menu: :investment)

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    min_date = current_user.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = current_user.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    @years = (min_date.year..max_date.year)
    @default_year = @investment.year
    @active_month_years = [ Date.new(@investment.year, @investment.month, 1).strftime("%Y%m").to_i ]
    set_all_categories
    set_entities
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_investment
    @investment = Investment.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def investment_params
    ret_params = params.require(:investment)
    ret_params[:value] = ret_params[:value].to_i if ret_params[:value].present?

    ret_params.permit(:description, :value, :inclusive, :month, :year, :active, :user_id,
                      budget_categories_attributes: %i[id category_id _destroy],
                      budget_entities_attributes: %i[id entity_id _destroy])
  end
end
