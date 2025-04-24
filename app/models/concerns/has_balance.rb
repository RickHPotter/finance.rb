# frozen_string_literal: true

module HasBalance
  extend ActiveSupport::Concern

  included do
    validates :order_id, presence: true

    before_validation :recalculate_balances
    before_destroy :recalculate_balances
  end

  protected

  def recalculate_balances # rubocop:disable Metrics/AbcSize
    # TODO: because this runs BEFORE validation, then all these conditions must be set, unfortunately
    return if user.nil? || this_price.nil? || this_year.nil? || this_month.nil?

    past_cash_installment = custom_sort_by(cash_installments_from_before).last
    past_budget           = budgets_from_before.last
    cash_installments     = custom_sort_by([ self ] + cash_installments_from_now - [ self ])

    next_order_id   = [ past_cash_installment&.order_id, past_budget&.order_id, -1 ].compact.max
    running_balance = past_cash_installment&.balance || past_budget&.balance || 0

    items(cash_installments:).each do |item|
      running_balance += item.is_a?(CashInstallment) ? item.price : item.remaining_value
      next_order_id += 1

      if item == self
        self.balance = running_balance
        self.order_id = next_order_id
      else
        item.update_columns(balance: running_balance, order_id: next_order_id)
      end
    end
  end

  def items(cash_installments: cash_installments_from_now, budgets: budgets_from_now)
    transactions = [ self ]
    transactions << (cash_installments - [ self ])
    transactions << budgets

    custom_sort_by(transactions.flatten)
  end

  def cash_installments_from_before
    user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month < ?)", this_year, this_year, this_month).order(:order_id)
  end

  def cash_installments_from_now
    user.cash_installments.where("date_year > ? OR (date_year = ? AND date_month >= ?)", this_year, this_year, this_month).order(:order_id)
  end

  def budgets_from_before
    user.budgets.where("year < ? OR (year = ? AND month < ?)", this_year, this_year, this_month).order(:order_id)
  end

  def budgets_from_now
    user.budgets.where("year > ? OR (year = ? AND month >= ?)", this_year, this_year, this_month).order(:order_id)
  end

  def custom_sort_by(items)
    items.sort_by do |item|
      if item.is_a?(CashInstallment)
        [
          item.date_year,
          item.date_month,
          item.date,
          # FIXME: too slow -> item.cash_transaction.investment? ? 0 : 1,
          1,
          item.price * -1,
          item.id || 1_000_000_000
        ]
      else
        [
          item.year,
          item.month,
          Date.new(item.year, item.month, 1),
          2,
          item.remaining_value * -1,
          item.id || 1_000_000_000
        ]
      end
    end
  end

  def this_year
    if instance_of?(CashInstallment)
      attributes["date_year"].presence || self.date_year = date.year
    else
      year
    end
  end

  def this_month
    if instance_of?(CashInstallment)
      attributes["date_month"] || self.date_month = date.month
    else
      month
    end
  end

  def this_price
    respond_to?(:price) ? price : remaining_value
  end
end
