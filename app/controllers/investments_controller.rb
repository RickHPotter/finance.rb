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

    investments = Logic::Investments.find_ref_month_year_by_params(current_context, investment_params, search_investment_params)

    render Views::Investments::MonthYear.new(mobile: @mobile, month_year:, month_year_str:, investments:, current_user:)
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
    @investment.date += 1.day if params[:next_day]
    @chain_context = current_chain_context(mode: "create")

    respond_to do |format|
      format.html { render Views::Investments::New.new(current_user:, investment: @investment, chain_context: @chain_context) }
      format.turbo_stream
    end
  end

  def duplicate
    existing_investment = current_context.investments.find(params[:id])
    @investment = existing_investment.dup
    @investment.duplicate = true
    @investment.price = 0
    @investment.date = existing_investment.date + 1.day
    @investment.month = @investment.date.month
    @investment.year = @investment.date.year
    @chain_context = current_chain_context(mode: "duplicate")

    render Views::Investments::New.new(current_user:, investment: @investment, chain_context: @chain_context)
  end

  def create
    if finish_chain_without_save_requested?
      handle_chain_finish_without_save
      return
    end

    @investment = Logic::Investments.create(investment_params.merge(user: current_user, context: current_context))
    @chain_context = current_chain_context

    handle_chain_save_success if @investment&.errors&.empty?

    respond_to(&:turbo_stream)
  end

  def edit
    respond_to do |format|
      format.html { render Views::Investments::Edit.new(current_user:, investment: @investment) }
      format.turbo_stream
    end
  end

  def update
    @investment = Logic::Investments.update(@investment, investment_params.merge(user: current_user, context: current_context))

    load_based_on_save if @investment

    respond_to(&:turbo_stream)
  end

  def destroy
    @investment.destroy
    build_index_context

    respond_to(&:turbo_stream)
  end

  def load_based_on_save
    load_based_on_affected_investments(current_context.investments.where(id: @investment.id))
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
      count_by_month_year:
    }
  end

  def handle_chain_save_success
    created_record_ids = updated_chain_record_ids(@investment.id)

    if continue_chain?
      @chain_context = current_chain_context(record_ids: created_record_ids, checked: true)
      @next_investment = next_investment_for_chain
      return
    end

    load_based_on_affected_investments(current_context.investments.where(id: created_record_ids))
  end

  def handle_chain_finish_without_save
    @finished_chain_without_save = true
    @investment = current_context.investments.new
    load_based_on_affected_investments(current_context.investments.where(id: current_chain_record_ids))

    respond_to(&:turbo_stream)
  end

  def load_based_on_affected_investments(investments)
    investments = investments.to_a

    if investments.empty?
      build_index_context
      return
    end

    active_month_years = investments.map { |investment| Date.new(investment.year, investment.month).strftime("%Y%m").to_i }.uniq
    index_filters = affected_investment_filters(investments)
    count_by_month_year = Logic::Investments.find_count_based_on_search(current_context, index_filters, search_investment_params)

    @index_context = {
      current_user:,
      years: investment_years,
      default_year: active_month_years.max.to_s.first(4).to_i,
      active_month_years:,
      **index_filters,
      count_by_month_year:
    }
  end

  def affected_investment_filters(investments)
    {
      user_bank_account_id: investments.map(&:user_bank_account_id).compact.uniq,
      investment_type_id: investments.map(&:investment_type_id).compact.uniq
    }.compact_blank
  end

  def investment_years
    min_date = current_context.investments.minimum("MAKE_DATE(year, month, 1)") || Time.zone.today
    max_date = current_context.investments.maximum("MAKE_DATE(year, month, 1)") || Time.zone.today

    (min_date.year..max_date.year)
  end

  def next_investment_for_chain
    return duplicate_investment_sample(@investment) if current_chain_context[:mode] == "duplicate"

    current_context.investments.new(user: current_user, date: Time.zone.now)
  end

  def duplicate_investment_sample(existing_investment)
    existing_investment.dup.tap do |investment|
      investment.duplicate = true
      investment.price = 0
      investment.date = existing_investment.date + 1.day
      investment.month = investment.date.month
      investment.year = investment.date.year
    end
  end

  def current_chain_context(mode: nil, record_ids: current_chain_record_ids, checked: continue_chain_requested?)
    {
      mode: mode || params[:chain_mode].presence || "create",
      record_ids:,
      checked:
    }
  end

  def current_chain_record_ids
    Array(params[:chain_record_ids]).compact_blank.map(&:to_i)
  end

  def updated_chain_record_ids(current_record_id)
    (current_chain_record_ids + [ current_record_id ]).uniq
  end

  def continue_chain?
    continue_chain_requested? && !finish_chain_requested?
  end

  def continue_chain_requested?
    ActiveModel::Type::Boolean.new.cast(params[:continue_chain])
  end

  def finish_chain_requested?
    ActiveModel::Type::Boolean.new.cast(params[:finish_chain])
  end

  def finish_chain_without_save_requested?
    ActiveModel::Type::Boolean.new.cast(params[:finish_chain_without_save])
  end

  private

  def set_investment_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :investment)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_investment
    @investment = current_context.investments.find(params[:id])
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
      user_bank_account_id: [], investment_type_id: [], id: []
    )
  end
end
