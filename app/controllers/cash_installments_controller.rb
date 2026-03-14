# frozen_string_literal: true

class CashInstallmentsController < ApplicationController
  include TranslateHelper

  before_action :set_cash_installment, only: %i[pay]

  def pay # rubocop:disable Metrics/AbcSize
    cash_installment_date  = @cash_installment.date
    cash_installment_price = @cash_installment.price

    price = cash_installment_price
    date  = Time.zone.now

    price = cash_installment_params[:price].to_i            if cash_installment_params[:price].present?
    date  = Time.zone.parse(cash_installment_params[:date]) if cash_installment_params[:date].present?

    min_date = [ cash_installment_date, date ].min

    @cash_installment = update_installment(@cash_installment, date, price)

    if cash_installment_price != price
      if cash_installment_date.strftime("%Y%m%d").to_i > date.strftime("%Y%m%d").to_i
        cash_installment_date
      else
        cash_installment_date + 1.day
      end => new_date

      Logic::Manipulation::CashInstallment.new(@cash_installment).split_installment(new_date, cash_installment_price - price)
    end

    Logic::RecalculateBalancesService.new(user: current_user, year: min_date.year, month: min_date.month).call

    handle_save
  end

  def pay_multiple
    date = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    cash_installments = selected_cash_installments
    return handle_empty_selection if cash_installments.empty?

    min_date = [ *cash_installments.pluck(:date), date ].min

    cash_installments.each do |cash_installment|
      update_installment(cash_installment, date)
    end

    Logic::RecalculateBalancesService.new(user: current_user, year: min_date.year, month: min_date.month).call

    @cash_installment = cash_installments.first

    handle_save
  end

  def update_installment(cash_installment, date, price = nil)
    params = { date:, paid: true }
    params.merge!(year: date.year, month: date.month) if cash_installment.date.month != date.month
    params.merge!(price:) if price

    cash_installment.update(params)
    cash_installment
  end

  def transfer_multiple
    cash_installments = selected_cash_installments
    return handle_empty_selection if cash_installments.empty?

    year, month       = params[:reference_date].split("-").map(&:to_i)
    date              = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    min_date          = [ *cash_installments.pluck(:date), date ].min

    cash_installments.update_all(date:, year:, month:)

    Logic::RecalculateBalancesService.new(user: current_user, year: min_date.year, month: min_date.month).call

    @cash_installment = cash_installments.first

    handle_save
  end

  def handle_save
    build_index_context_from_selection || build_index_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(:updateda, CashInstallment) })
        ]
      end
    end
  end

  def build_index_context # rubocop:disable Metrics/MethodLength
    date = Date.new(@cash_installment.year, @cash_installment.month)
    active_month_years = [ date.strftime("%Y%m").to_i ]
    years = [ date.year ]
    default_year = years.first

    count_by_month_year = Logic::CashTransactions.find_count_based_on_search(current_user, {}, {})

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      category_id: "",
      entity_id: "",
      from_ct_price: nil,
      to_ct_price: nil,
      from_price: nil,
      to_price: nil,
      from_installments_count: nil,
      to_installments_count: nil,
      from_date: nil,
      to_date: nil,
      user_card: @user_card,
      count_by_month_year:
    }
  end

  def build_index_context_from_selection # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return false if params[:index_context_json].blank?

    context = JSON.parse(params[:index_context_json]).with_indifferent_access
    cash_installments = current_user.cash_installments
    today_zn = Time.zone.today.beginning_of_month

    min_year = cash_installments.minimum("installments.year") || today_zn.year
    max_year = cash_installments.maximum("installments.year") || today_zn.year
    years = (min_year..max_year)

    category_id = Array(context[:category_id]).compact_blank
    entity_id = Array(context[:entity_id]).compact_blank
    cash_installment_ids = Array(context[:cash_installment_ids]).compact_blank
    user_bank_account_id = Array(context[:user_bank_account_id]).compact_blank
    search_term = context[:search_term]
    from_ct_price = context[:from_ct_price]
    to_ct_price = context[:to_ct_price]
    from_price = context[:from_price]
    to_price = context[:to_price]
    from_installments_count = context[:from_installments_count]
    to_installments_count = context[:to_installments_count]
    from_date = context[:from_date]
    to_date = context[:to_date]
    paid = ActiveModel::Type::Boolean.new.cast(context[:paid])
    pending = ActiveModel::Type::Boolean.new.cast(context[:pending])
    skip_budgets = context[:skip_budgets]
    force_mobile = ActiveModel::Type::Boolean.new.cast(context[:force_mobile])
    active_month_years = Array(context[:active_month_years]).map(&:to_i)
    default_year = context[:default_year].presence&.to_i
    default_year ||= active_month_years.max.to_s.first(4).to_i if active_month_years.any?
    default_year ||= today_zn.year

    cash_transaction_filters = {
      category_id:,
      entity_id:,
      cash_installment_ids:,
      user_bank_account_id:
    }
    search_filters = {
      search_term:,
      from_ct_price:,
      to_ct_price:,
      from_price:,
      to_price:,
      from_installments_count:,
      to_installments_count:,
      from_date:,
      to_date:,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:
    }

    count_by_month_year = Logic::CashTransactions.find_count_based_on_search(current_user, cash_transaction_filters, search_filters)

    @mobile = force_mobile
    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      category_id:,
      entity_id:,
      cash_installment_ids:,
      user_bank_account_id:,
      from_ct_price:,
      to_ct_price:,
      from_price:,
      to_price:,
      from_installments_count:,
      to_installments_count:,
      from_date:,
      to_date:,
      user_card: @user_card,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:,
      count_by_month_year:
    }
  end

  def selected_cash_installments
    current_user.cash_installments.includes(:cash_transaction).where(id: selected_ids, paid: false).order(:order_id)
  end

  def selected_ids
    case params[:ids]
    when String then params[:ids].split(",").compact_blank
    when Array then params[:ids].flatten.compact_blank
    else []
    end
  end

  def handle_empty_selection
    build_index_context_from_selection || build_index_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: notification_model(:not_updateda, CashInstallment) })
        ]
      end
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_installment
    @cash_installment = current_user.cash_installments.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def cash_installment_params
    params.require(:cash_installment).permit(:price, :date)
  end
end
