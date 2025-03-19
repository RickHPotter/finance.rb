# frozen_string_literal: true

class CashInstallmentsController < ApplicationController
  include TranslateHelper

  def pay
    cash_installment_params = params.require(:cash_installment).permit(:date)
    date = cash_installment_params[:date].to_datetime || DateTime.current

    @cash_installment = current_user.cash_installments.find(params[:id])
    @cash_installment.update(date:, paid: true)
    @cash_installment.balance = params[:balance]

    respond_to do |format|
      @mobile = true
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(@cash_installment, partial: "cash_installments/cash_installment", locals: { cash_installment: @cash_installment }),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(:updateda, CashInstallment) })
        ]
      end
    end
  end
end
