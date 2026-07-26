# frozen_string_literal: true

class BudgetsController < ApplicationController
  include TabsConcern

  before_action :set_budget, only: %i[show edit update destroy]
  before_action :set_budget_tabs

  def index
    build_index_context
    @index_context[:return_to] = budget_navigation_return_param(request.fullpath)

    render_top_level Views::Budgets::Index.new(index_context: @index_context, mobile: @mobile)
  end

  def month_year
    month_year     = search_budget_params[:month_year]
    year           = month_year[0..3].to_i
    month          = month_year[4..].to_i
    month_year_str = I18n.l(Date.new(year, month, 1), format: "%B %Y")

    budgets = Logic::Budgets.find_by_ref_month_year_by_params(current_context, month, year, budget_params.merge(search_budget_params.slice(:search_term)))

    render Views::Budgets::MonthYear.new(
      mobile: @mobile,
      month_year:,
      month_year_str:,
      budgets:,
      category_colour_display_mode:,
      return_to: budget_navigation_return_param(params[:return_to])
    )
  end

  def show
    set_return_to
    render_top_level Views::Budgets::Show.new(budget: @budget, return_to: @return_to)
  end

  def new
    @budget = current_context.budgets.new(user: current_user)
    set_return_to
    render_top_level Views::Budgets::New.new(current_user:, budget: @budget, return_to: @return_to)
  end

  def create
    @budget = Logic::Budgets.create(budget_params.merge(user: current_user, context: current_context), multiple_budget_params)

    handle_save
  end

  def edit
    set_return_to
    render_top_level Views::Budgets::Edit.new(current_user:, budget: @budget, return_to: @return_to)
  end

  def duplicate
    @budget = current_context.budgets.duplicate(params[:id])
    set_return_to
    render_top_level Views::Budgets::New.new(current_user:, budget: @budget, return_to: @return_to)
  end

  def update
    @budget = Logic::Budgets.update(@budget, budget_params.merge(user: current_user, context: current_context))

    handle_save
  end

  def destroy
    set_return_to
    @budget.destroy

    if @budget.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyed, Budget), status: :see_other
    else
      respond_to do |format|
        format.html { render Views::Budgets::Show.new(budget: @budget, return_to: @return_to), status: :unprocessable_content }
        format.turbo_stream { render :destroy, status: :unprocessable_content }
      end
    end
  end

  def bulk_update
    Audit::BulkMutation.update_all!(selected_budgets, bulk_budget_attributes.merge(updated_at: Time.current))
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
    set_return_to
    return render_budget_failure unless @budget.valid?

    set_tabs(active_menu: :cash, active_sub_menu: :pix) if @budget.active?
    redirect_to budget_save_destination,
                notice: notification_model(action_name == "create" ? :created : :updated, Budget),
                status: :see_other
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

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_budget_failure
    view =
      if action_name == "create"
        Views::Budgets::New.new(current_user:, budget: @budget, return_to: @return_to)
      else
        Views::Budgets::Edit.new(current_user:, budget: @budget, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def budget_save_destination
    return @return_to unless @budget.active?

    cash_transactions_path(
      default_year: @budget.year,
      active_month_years: [ Date.new(@budget.year, @budget.month, 1).strftime("%Y%m").to_i ].to_json
    )
  end

  def set_return_to
    @return_to = budget_navigation_destination(params[:return_to])
  end

  def budget_navigation_destination(raw)
    Navigation::Budgets.new(raw:, fallback: budgets_path, current_user:, current_context:).destination
  end

  def budget_navigation_return_param(raw)
    destination = budget_navigation_destination(raw)
    destination unless destination == budgets_path
  end

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
    return budget_navigation_destination(raw_return_path) if uri.path == budgets_path
    if uri.path == cash_transactions_path
      return Navigation::CashTransactions.new(raw: raw_return_path, fallback: cash_transactions_path, current_user:,
                                              current_context:).destination
    end

    nil
  rescue URI::InvalidURIError
    nil
  end
end
