# frozen_string_literal: true

class InvestmentsController < ApplicationController
  include TabsConcern

  before_action :set_investment, only: %i[edit update destroy]
  before_action :set_investment_tabs

  def index
    build_index_context
    @index_context[:return_to] = investment_navigation_return_param(request.fullpath)

    render_top_level Views::Investments::Index.new(index_context: @index_context, mobile: @mobile)
  end

  def month_year
    month_year = search_investment_params[:month_year]
    month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

    investments = Logic::Investments.find_ref_month_year_by_params(current_context, investment_params, search_investment_params)

    render Views::Investments::MonthYear.new(
      mobile: @mobile,
      month_year:,
      month_year_str:,
      investments:,
      current_user:,
      return_to: investment_navigation_return_param(params[:return_to])
    )
  end

  def new
    user_bank_account_id = investment_params[:user_bank_account_id]
    investment_type_id = investment_params[:investment_type_id]

    @investment = current_context.investments.new(user: current_user, user_bank_account_id:, investment_type_id:)

    if user_bank_account_id && investment_type_id
      investments = @investment.user_bank_account.investments.where(investment_type_id:)
      @investment.date = investments.maximum(:date)
    end

    @investment.date ||= Time.zone.now
    @investment.date += 1.day if next_day_duplicate_requested?
    @investment.duplicate = next_day_duplicate_requested?
    @chain_context = current_chain_context(mode: chain_mode_for_new_investment)
    set_return_to

    render_top_level Views::Investments::New.new(current_user:, investment: @investment, chain_context: @chain_context, return_to: @return_to)
  end

  def duplicate
    existing_investment = current_context.investments.find(params[:id])
    @investment = existing_investment.dup
    @investment.duplicate = true
    @investment.price = 0
    @investment.date = existing_investment.date
    @investment.month = @investment.date.month
    @investment.year = @investment.date.year
    @chain_context = current_chain_context(mode: "duplicate")
    set_return_to

    render_top_level Views::Investments::New.new(current_user:, investment: @investment, chain_context: @chain_context, return_to: @return_to)
  end

  def create
    if finish_chain_without_save_requested?
      handle_chain_finish_without_save
      return
    end

    @investment = Logic::Investments.create(investment_params.merge(user: current_user, context: current_context))
    @chain_context = current_chain_context
    set_return_to

    return render_investment_failure if @investment.blank? || @investment.errors.any?

    redirect_to handle_chain_save_success, notice: notification_model(:created, Investment), status: :see_other
  end

  def edit
    set_return_to
    render_top_level Views::Investments::Edit.new(current_user:, investment: @investment, return_to: @return_to)
  end

  def update
    @investment = Logic::Investments.update(@investment, investment_params.merge(user: current_user, context: current_context))
    set_return_to

    return render_investment_failure if @investment.blank? || @investment.errors.any?

    redirect_to @return_to, notice: notification_model(:updated, Investment), status: :see_other
  end

  def destroy
    set_return_to
    @investment.destroy

    if @investment.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyed, Investment), status: :see_other
    else
      respond_to do |format|
        format.html { render Views::Investments::Edit.new(current_user:, investment: @investment, return_to: @return_to), status: :unprocessable_content }
        format.turbo_stream { render :destroy, status: :unprocessable_content }
      end
    end
  end

  def build_index_context # rubocop:disable Metrics/AbcSize
    min_date = current_context.investments.minimum("MAKE_DATE(year, month, 1)") || Time.zone.today
    max_date = current_context.investments.maximum("MAKE_DATE(year, month, 1)") || Time.zone.today
    default_active_month_years = [ [ max_date, Time.zone.today ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)
    default_year = params[:default_year]&.to_i || [ max_date, Time.zone.today ].min.year
    active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years

    search_term = search_investment_params[:search_term]
    investment_ids = [ investment_params[:id] ].flatten&.compact_blank
    user_bank_account_id = [ investment_params[:user_bank_account_id] ].flatten&.compact_blank
    investment_type_id = [ investment_params[:investment_type_id] ].flatten&.compact_blank
    piggy_bank_return_cash_transaction_id = [ investment_params[:piggy_bank_return_cash_transaction_id] ].flatten&.compact_blank

    count_by_month_year = Logic::Investments.find_count_based_on_search(current_context, investment_params, search_investment_params)

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      id: investment_ids,
      user_bank_account_id:,
      investment_type_id:,
      piggy_bank_return_cash_transaction_id:,
      count_by_month_year:
    }
  end

  def handle_chain_save_success
    created_record_ids = updated_chain_record_ids(@investment.id)

    return chain_continuation_destination(created_record_ids) if continue_chain?
    return chain_index_destination(created_record_ids) if chain_workflow?

    @return_to
  end

  def handle_chain_finish_without_save
    set_return_to
    redirect_to chain_index_destination(current_chain_record_ids), status: :see_other
  end

  def chain_continuation_destination(record_ids)
    options = {
      chain_mode: current_chain_context[:mode],
      chain_record_ids: record_ids,
      continue_chain: "1",
      return_to: @return_to
    }

    if current_chain_context[:mode] == "duplicate" && !next_day_duplicate_requested?
      duplicate_investment_path(@investment, **options)
    else
      new_investment_path(
        investment: @investment.slice(:user_bank_account_id, :investment_type_id),
        next_day: ("1" if next_day_duplicate_requested?),
        **options
      )
    end
  end

  def chain_index_destination(record_ids)
    investments = current_context.investments.where(id: record_ids)
    return @return_to if investments.empty?

    months = investments.map { |investment| Date.new(investment.year, investment.month).strftime("%Y%m").to_i }.uniq
    filters = affected_investment_filters(investments)
    destination = investments_path(
      default_year: months.max.to_s.first(4).to_i,
      active_month_years: months.to_json,
      investment: filters
    )
    investment_navigation_destination(destination)
  end

  def affected_investment_filters(investments)
    piggy_bank_return_ids = investments.where.not(piggy_bank_return_cash_transaction_id: nil)
                                       .distinct
                                       .pluck(:piggy_bank_return_cash_transaction_id)
    all_piggy_bank_returns = !investments.where(piggy_bank_return_cash_transaction_id: nil).exists?
    return { piggy_bank_return_cash_transaction_id: piggy_bank_return_ids } if piggy_bank_return_ids.present? && all_piggy_bank_returns

    {
      user_bank_account_id: investments.distinct.pluck(:user_bank_account_id).compact,
      investment_type_id: investments.distinct.pluck(:investment_type_id).compact
    }.compact_blank
  end

  def current_chain_context(mode: nil, record_ids: current_chain_record_ids, checked: continue_chain_requested?)
    {
      mode: mode || params[:chain_mode].presence || "create",
      record_ids:,
      checked:
    }
  end

  def current_chain_record_ids
    raw_ids = Array(params[:chain_record_ids]).compact_blank.map(&:to_s)
    return [] if raw_ids.size > Navigation::State::MAX_VALUES
    return [] unless raw_ids.all? { |id| id.match?(/\A[1-9]\d*\z/) }

    ids = raw_ids.map(&:to_i).uniq
    owned_ids = current_context.investments.where(id: ids).ids
    owned_ids.sort == ids.sort ? ids : []
  end

  def updated_chain_record_ids(current_record_id)
    (current_chain_record_ids + [ current_record_id ]).uniq
  end

  def continue_chain?
    continue_chain_requested? && !finish_chain_requested?
  end

  def continue_chain_requested? = ActiveModel::Type::Boolean.new.cast(params[:continue_chain])

  def finish_chain_requested? = ActiveModel::Type::Boolean.new.cast(params[:finish_chain])

  def finish_chain_without_save_requested? = ActiveModel::Type::Boolean.new.cast(params[:finish_chain_without_save])

  def chain_workflow? = current_chain_record_ids.any? || params[:chain_mode].present?

  private

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_investment_failure
    view =
      if action_name == "create"
        Views::Investments::New.new(current_user:, investment: @investment, chain_context: @chain_context, return_to: @return_to)
      else
        Views::Investments::Edit.new(current_user:, investment: @investment, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def set_return_to
    @return_to = investment_navigation_destination(params[:return_to])
  end

  def investment_navigation_destination(raw)
    Navigation::Investments.new(raw:, fallback: investments_path, current_user:, current_context:).destination
  end

  def investment_navigation_return_param(raw)
    destination = investment_navigation_destination(raw)
    destination unless destination == investments_path
  end

  def next_day_duplicate_requested? = ActiveModel::Type::Boolean.new.cast(params[:next_day])

  def chain_mode_for_new_investment = next_day_duplicate_requested? ? "duplicate" : "create"

  def set_investment_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :investment)
  end

  def set_investment
    @investment = current_context.investments.find(params[:id])
  end

  def search_investment_params
    params.permit(%i[search_term month_year])
  end

  def investment_params
    return {} if params[:investment].blank?

    ret_params = params.require(:investment)
    ret_params[:price] = ret_params[:price].to_i if ret_params[:price].present?

    ret_params.permit(
      :description, :price, :date, :month, :year, :user_id, :user_bank_account_id, :investment_type_id, :piggy_bank_return_cash_transaction_id,
      user_bank_account_id: [], investment_type_id: [], piggy_bank_return_cash_transaction_id: [], id: []
    )
  end
end
