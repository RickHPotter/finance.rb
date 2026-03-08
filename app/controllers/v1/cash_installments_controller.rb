# frozen_string_literal: true

class V1::CashInstallmentsController < V1::ApplicationController
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

    cash_installments = CashInstallment.where(id: params[:ids]).order(:order_id)
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
    cash_installments = CashInstallment.where(id: params[:ids]).order(:order_id)
    year, month       = params[:reference_date].split("-").map(&:to_i)
    date              = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    min_date          = [ *cash_installments.pluck(:date), date ].min

    cash_installments.update_all(date:, year:, month:)

    Logic::RecalculateBalancesService.new(user: current_user, year: min_date.year, month: min_date.month).call

    @cash_installment = cash_installments.first

    handle_save
  end

  def handle_save
    build_index_context

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

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_installment
    @cash_installment = current_user.cash_installments.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def cash_installment_params
    params.require(:cash_installment).permit(:price, :date)
  end
end
