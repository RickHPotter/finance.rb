# frozen_string_literal: true

class Logic::Finder::CurrentBalanceJson
  def initialize(user:, context: user.main_context)
    @user = user
    @context = context
  end

  def call
    return empty_payload if latest_paid_installment.blank?

    {
      current_value: latest_paid_installment.balance.to_f / 100,
      previous_value: (previous_paid_installment&.balance.to_f / 100) || (latest_paid_installment.balance.to_f / 100),
      current_month_year: (latest_paid_installment.year * 100) + latest_paid_installment.month
    }
  end

  private

  def latest_paid_installment
    @latest_paid_installment ||= @context.cash_installments.where(paid: true).order(:date, :id).last
  end

  def previous_paid_installment
    return if latest_paid_installment.blank?

    @previous_paid_installment ||=
      @context.cash_installments
              .where(paid: true)
              .where("installments.date < ? OR (installments.date = ? AND installments.id < ?)",
                     latest_paid_installment.date, latest_paid_installment.date, latest_paid_installment.id)
              .order(:order_id)
              .last
  end

  def empty_payload
    {
      current_value: 0,
      previous_value: 0,
      current_month_year: nil
    }
  end
end
