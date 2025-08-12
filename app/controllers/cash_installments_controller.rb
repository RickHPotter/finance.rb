# frozen_string_literal: true

class CashInstallmentsController < ApplicationController
  include TranslateHelper

  def pay
    date = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now

    @cash_installment = current_user.cash_installments.find(params[:id])
    @cash_installment.update(date:, paid: true)

    Logic::RecalculateBalancesService.new(user: current_user, year: @cash_installment.year, month: @cash_installment.month).call

    build_index_context

    respond_to do |format|
      @mobile = true
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(:updateda, CashInstallment) })
        ]
      end
    end
  end

  def pay_multiple
    date = Time.zone.parse(cash_installment_params[:date]) || Time.zone.now
    cash_installments = CashInstallment.where(id: params[:ids]).order(:order_id)
    cash_installments.update(date:, paid: true)

    Logic::RecalculateBalancesService.new(user: current_user, year: cash_installments.first.year, month: cash_installments.first.month).call

    @cash_installment = cash_installments.first
    build_index_context

    respond_to do |format|
      @mobile = true
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(:updateda, CashInstallment) })
        ]
      end
    end
  end

  def build_index_context
    date = Date.new(@cash_installment.year, @cash_installment.month)
    active_month_years = [ date.strftime("%Y%m").to_i ]
    years = [ date.year ]
    default_year = years.first

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
      user_card: @user_card
    }
  end

  # Only allow a list of trusted parameters through.
  def cash_installment_params
    params.require(:cash_installment).permit(:date)
  end
end
