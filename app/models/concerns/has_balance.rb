# frozen_string_literal: true

module HasBalance
  extend ActiveSupport::Concern

  included do
    before_validation :set_balance, if: -> { user.present? && balance.nil? }
    before_save :recalculate_balances
    before_destroy :recalculate_balances
  end

  protected

  def set_balance
    return if this_price.nil?

    self.balance = running_balance_for_self
  end

  def running_balance_for_self
    items = (user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month <= ?)", this_year, this_year, this_month).to_a +
             user.budgets.where("year < ? OR (year = ? AND month <= ?)", this_year, this_year, this_month).to_a)
            .sort_by { |item| [ item.date || Date.new(item.year, item.month, 1), item.id ] }

    running_balance = 0
    items.each do |item|
      running_balance += item.is_a?(CashInstallment) ? item.price : item.remaining_value
    end
    running_balance
  end

  def recalculate_balances
    past_installments = user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month < ?)", this_year, this_year, this_month).sum(:price)
    past_budgets      = user.budgets.where("year < ? OR (year = ? AND month < ?)", this_year, this_year, this_month).sum(:remaining_value)
    running_balance   = past_installments + past_budgets

    items.each do |item|
      running_balance += item.is_a?(CashInstallment) ? item.price : item.remaining_value
      item.update_columns(balance: running_balance)
    end
  end

  def items
    cash_installments = user.cash_installments.where("date_year > ? OR (date_year = ? AND date_month >= ?)", this_year, this_year, this_month).to_a
    budgets = user.budgets.where("year > ? OR (year = ? AND month >= ?)", this_year, this_year, this_month).to_a

    (cash_installments + budgets).sort_by do |item|
      year  = item.respond_to?(:date_year) ? item.date_year : item.year
      month = item.respond_to?(:date_month) ? item.date_month : item.month
      date  = item.respond_to?(:date) && item.date ? item.date : Date.new(year, month, 1)
      type  = item.is_a?(CashInstallment) ? 0 : 1
      [ year, month, date, type, item.id ]
    end
  end

  def this_year
    if instance_of?(CashInstallment)
      attributes["date_year"]
    else
      year
    end
  end

  def this_month
    if instance_of?(CashInstallment)
      attributes["date_month"]
    else
      month
    end
  end

  def this_price
    respond_to?(:price) ? price : remaining_value
  end
end
