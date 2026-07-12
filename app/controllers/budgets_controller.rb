# frozen_string_literal: true

class BudgetsController < ApplicationController
  include TabsConcern

  before_action :set_budget, only: %i[show edit update destroy]
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

    budgets = Logic::Budgets.find_by_ref_month_year_by_params(current_context, month, year, budget_params.merge(search_budget_params.slice(:search_term)))

    render Views::Budgets::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, budgets:)
  end

  def show
    render Views::Budgets::Show.new(budget: @budget)
  end

  def new
    @budget = current_context.budgets.new(user: current_user)

    respond_to do |format|
      format.html { render Views::Budgets::New.new(current_user:, budget: @budget) }
      format.turbo_stream
    end
  end

  def create
    @budget = Logic::Budgets.create(budget_params.merge(user: current_user, context: current_context), multiple_budget_params)

    handle_save
  end

  def edit
    respond_to do |format|
      format.html { render Views::Budgets::Edit.new(current_user:, budget: @budget) }
      format.turbo_stream
    end
  end

  def duplicate
    @budget = current_context.budgets.duplicate(params[:id])

    respond_to do |format|
      format.html { render Views::Budgets::New.new(current_user:, budget: @budget) }
      format.turbo_stream { render Views::Budgets::New.new(current_user:, budget: @budget) }
    end
  end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params.merge(user: current_user, context: current_context))

    handle_save
  end

  def destroy
    @budget.destroy
    build_index_context

    respond_to(&:turbo_stream)
  end

  def bulk_update
    selected_budgets.update_all(bulk_budget_attributes.merge(updated_at: Time.current))
    recalculate_selected_budget_balances
    redirect_to_bulk_return_path(:updated) && return

    build_index_context

    render_bulk_success(:updated)
  end

  def bulk_destroy
    selected_budgets.find_each(&:destroy)
    redirect_to_bulk_return_path(:destroyed) && return

    build_index_context

    render_bulk_success(:destroyed)
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
    min_date = current_context.cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    max_date = current_context.cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    @years = (min_date.year..max_date.year)
    @default_year = @budget.year
    @active_month_years = [ Date.new(@budget.year, @budget.month, 1).strftime("%Y%m").to_i ]
  end

  def build_index_context
    @index_context = IndexState::Budgets.new(
      current_user:,
      current_context:,
      params:,
      budget_filters: budget_params,
      search_filters: search_budget_params,
      years: @years,
      default_year: @default_year,
      active_month_years: @active_month_years
    ).to_h
  end

  private

  def set_budget_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :budget)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_budget
    @budget = current_context.budgets.find(params[:id])
  end

  def search_budget_params
    params.permit(:search_term, :month_year, :sort, :direction)
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

  def selected_budgets
    current_context.budgets.where(id: selected_budget_ids)
  end

  def selected_budget_ids
    params[:ids].to_s.split(",").filter_map { |id| Integer(id, exception: false) }.uniq
  end

  def bulk_budget_attributes
    case params[:bulk_action]
    when "make_inclusive"
      { inclusive: true }
    when "make_exclusive"
      { inclusive: false }
    when "first_installment_only"
      { first_installment_only: true }
    when "all_installments"
      { first_installment_only: false }
    else
      {}
    end
  end

  def recalculate_selected_budget_balances
    selected_budgets.find_each do |budget|
      budget.set_remaining_value
      budget.save!
    end
  end

  def render_bulk_success(action)
    render turbo_stream: [
      turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(action, Budget) }),
      turbo_stream.replace(:center_container, Views::Budgets::Index.new(index_context: @index_context, mobile: @mobile))
    ]
  end

  def redirect_to_bulk_return_path(action)
    return false if bulk_return_path.blank?

    redirect_to bulk_return_path, notice: notification_model(action, Budget), status: :see_other
  end

  def bulk_return_path
    raw_return_path = params[:return_to].to_s
    return nil if raw_return_path.blank?

    uri = URI.parse(raw_return_path)
    return nil if uri.host.present? || uri.scheme.present?
    return nil unless [ budgets_path, cash_transactions_path ].include?(uri.path)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
