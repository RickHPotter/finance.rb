# frozen_string_literal: true

class CashInstallmentsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TranslateHelper

  before_action :set_cash_installment, only: %i[pay]

  def pay
    cash_installment_date  = @cash_installment.date
    cash_installment_price = @cash_installment.price

    price = cash_installment_price
    date  = Time.zone.now

    price = cash_installment_params[:price].to_i            if cash_installment_params[:price].present?
    date  = Time.zone.parse(cash_installment_params[:date]) if cash_installment_params[:date].present?

    min_date = [ cash_installment_date, date ].min
    @cash_installment = pay_installment(@cash_installment, date:, price:)
    return handle_failed_save(@cash_installment) if @cash_installment.errors.any?

    Logic::RecalculateBalancesService.new(user: current_user, context: current_context, year: min_date.year, month: min_date.month).call

    handle_save
  end

  def pay_multiple
    date = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    cash_installments = selected_cash_installments
    return handle_empty_selection if cash_installments.empty?

    min_date = [ *cash_installments.pluck(:date), date ].min

    cash_installments.each do |cash_installment|
      update_installment(cash_installment, date)
      return handle_failed_save(cash_installment) if cash_installment.errors.any?
    end

    Logic::RecalculateBalancesService.new(user: current_user, context: current_context, year: min_date.year, month: min_date.month).call

    @cash_installment = cash_installments.first

    handle_save
  end

  def partial_pay_multiple
    cash_installments = selected_cash_installments.to_a
    return handle_empty_selection if cash_installments.empty?

    partial_payment = build_partial_multiple_payment(cash_installments)
    return handle_invalid_partial_multiple_payment(partial_payment[:alert], cash_installments.first) unless partial_payment[:valid]

    failed_installment = apply_partial_multiple_payment(cash_installments, partial_payment)
    return handle_failed_save(failed_installment) if failed_installment.present?

    recalculate_balances_for(partial_payment[:min_date])

    handle_save
  end

  def update_installment(cash_installment, date, price = nil)
    params = { date:, paid: true }
    params.merge!(year: date.year, month: date.month) if cash_installment.date.month != date.month
    params.merge!(price:) if price

    cash_installment.update(params)
    cash_installment
  end

  def pay_installment(cash_installment, date:, price:)
    cash_installment_date = cash_installment.date
    cash_installment_price = cash_installment.price
    structure_change = cash_installment_price != price
    should_send_update_notification = structure_change && cash_installment.send(:shared_paid_state_transaction?)
    cash_installment.skip_shared_paid_state_sync = true if should_send_update_notification

    cash_installment = update_installment(cash_installment, date, price)
    return cash_installment if cash_installment.errors.any?

    if structure_change
      if cash_installment_date.strftime("%Y%m%d").to_i > date.strftime("%Y%m%d").to_i
        cash_installment_date
      else
        cash_installment_date + 1.day
      end => new_date

      Logic::Manipulation::CashInstallment.new(cash_installment).split_installment(new_date, cash_installment_price - price)
    end

    Logic::SharedPaidStateSyncService.new(installment: cash_installment, force_notify: true).call if should_send_update_notification

    cash_installment
  end

  def transfer_multiple
    cash_installments = selected_cash_installments
    return handle_empty_selection if cash_installments.empty?

    year, month       = params[:reference_date].split("-").map(&:to_i)
    date              = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    min_date          = [ *cash_installments.pluck(:date), date ].min

    cash_installments.each do |cash_installment|
      cash_installment.update(date:, year:, month:)
      return handle_failed_save(cash_installment) if cash_installment.errors.any?
    end

    Logic::RecalculateBalancesService.new(user: current_user, context: current_context, year: min_date.year, month: min_date.month).call

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

  def build_index_context
    date =
      if @cash_installment.present?
        Date.new(@cash_installment.year, @cash_installment.month)
      else
        Time.zone.today.beginning_of_month.to_date
      end

    active_month_years = [ date.strftime("%Y%m").to_i ]
    years = [ date.year ]
    default_year = years.first

    count_by_month_year = Logic::CashTransactions.find_count_based_on_search(current_context, {}, {})

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
      from_installments_number: nil,
      to_installments_number: nil,
      from_date: nil,
      to_date: nil,
      user_card: @user_card,
      count_by_month_year:,
      available_subscriptions: current_context.subscriptions.order(:description).to_a
    }
  end

  def build_index_context_from_selection # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return false if params[:index_context_json].blank?

    context = JSON.parse(params[:index_context_json]).with_indifferent_access
    cash_installments = current_context.cash_installments
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
    from_installments_number = context[:from_installments_number]
    to_installments_number = context[:to_installments_number]
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
      from_installments_number:,
      to_installments_number:,
      from_date:,
      to_date:,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:
    }

    count_by_month_year = Logic::CashTransactions.find_count_based_on_search(current_context, cash_transaction_filters, search_filters)

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
      from_installments_number:,
      to_installments_number:,
      from_date:,
      to_date:,
      user_card: @user_card,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:,
      count_by_month_year:,
      available_subscriptions: current_context.subscriptions.order(:description).to_a
    }
  end

  def selected_cash_installments
    current_context.cash_installments.includes(:cash_transaction).where(id: selected_ids, paid: false).order(:order_id)
  end

  def validate_partial_multiple_payment(cash_installments, requested_amount_cents:)
    partial_installment = cash_installments.find { |installment| installment.id.to_s == params[:partial_installment_id].to_s }
    return invalid_partial_multiple_payment(:invalid_selection) if partial_installment.blank?

    return invalid_partial_multiple_payment(:mixed_signs) if partial_multiple_payment_mixed_signs?(cash_installments)

    total_abs, largest_abs = partial_multiple_payment_totals(cash_installments)
    min_allowed, max_allowed = partial_multiple_payment_range(total_abs, largest_abs)
    requested_amount = requested_amount_cents.abs

    return invalid_partial_multiple_payment(:unavailable) if min_allowed > max_allowed
    return invalid_partial_multiple_payment(:invalid_amount) if requested_amount < min_allowed || requested_amount > max_allowed

    remaining_abs = total_abs - requested_amount
    partial_price = build_partial_price(partial_installment, remaining_abs)
    return invalid_partial_multiple_payment(:invalid_selection) if partial_price.blank?

    {
      valid: true,
      partial_installment:,
      partial_price:
    }
  end

  def build_partial_multiple_payment(cash_installments)
    date = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now
    validation = validate_partial_multiple_payment(cash_installments, requested_amount_cents: cash_installment_params[:price].to_i)

    validation.merge(
      date:,
      min_date: [ *cash_installments.map(&:date), date ].min
    )
  end

  def apply_partial_multiple_payment(cash_installments, partial_payment)
    skip_shared_paid_state_sync_for_partial_multiple(cash_installments, partial_payment[:partial_installment], partial_payment[:partial_price])

    cash_installments.each do |cash_installment|
      next if cash_installment.id == partial_payment[:partial_installment].id

      update_installment(cash_installment, partial_payment[:date])
      return cash_installment if cash_installment.errors.any?
    end

    @cash_installment = pay_installment(partial_payment[:partial_installment], date: partial_payment[:date], price: partial_payment[:partial_price])
    return @cash_installment if @cash_installment.errors.any?

    nil
  end

  def skip_shared_paid_state_sync_for_partial_multiple(cash_installments, partial_installment, partial_price)
    installments_requiring_sync_skip(cash_installments, partial_installment, partial_price).each do |installment|
      installment.skip_shared_paid_state_sync = true
    end
  end

  def partial_multiple_payment_mixed_signs?(cash_installments)
    signed_prices = cash_installments.map(&:price).reject(&:zero?).map(&:positive?)
    signed_prices.uniq.many?
  end

  def partial_multiple_payment_totals(cash_installments)
    total_abs = cash_installments.sum { |installment| installment.price.abs }
    largest_abs = cash_installments.map { |installment| installment.price.abs }.max || 0

    [ total_abs, largest_abs ]
  end

  def partial_multiple_payment_range(total_abs, largest_abs)
    [ total_abs - largest_abs + 1, total_abs - 1 ]
  end

  def build_partial_price(partial_installment, remaining_abs)
    partial_abs = partial_installment.price.abs - remaining_abs
    return if partial_abs <= 0

    partial_installment.price.positive? ? partial_abs : partial_abs * -1
  end

  def invalid_partial_multiple_payment(key)
    { valid: false, alert: I18n.t("bulk_actions.partial_pay.#{key}") }
  end

  def recalculate_balances_for(date)
    Logic::RecalculateBalancesService.new(user: current_user, context: current_context, year: date.year, month: date.month).call
  end

  def installments_requiring_sync_skip(cash_installments, partial_installment, partial_price)
    return [] unless partial_installment.price != partial_price
    return [] unless partial_installment.send(:shared_paid_state_transaction?)

    cash_installments.select { |installment| installment.cash_transaction_id == partial_installment.cash_transaction_id }
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

  def handle_invalid_partial_multiple_payment(alert, cash_installment)
    @cash_installment = cash_installment
    build_index_context_from_selection || build_index_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: })
        ], status: :unprocessable_content
      end
    end
  end

  def handle_failed_save(cash_installment)
    @cash_installment = cash_installment
    build_index_context_from_selection || build_index_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: @cash_installment.errors.full_messages.to_sentence })
        ], status: :unprocessable_content
      end
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_installment
    @cash_installment = current_context.cash_installments.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def cash_installment_params
    params.require(:cash_installment).permit(:price, :date)
  end
end
