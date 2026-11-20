# frozen_string_literal: true

# Proposes the date where the unpaid installments of a Piggy Bank return should land.
#
# The proposal is balance aware: the money still parked in the piggy bank is placed on the
# first point of the balance timeline that would turn negative without it. That keeps the
# balance history free of negatives caused by money the user cannot count on yet, and tells
# the user when the money can actually be counted on.
#
# The proposal never lands in the past. The piggy bank projection sync moves unpaid
# installments back to the return transaction date, so a reconciliation has to place them
# explicitly.
class PiggyBankReconciliations::CalculateSafeInstallmentDate
  attr_reader :user, :context, :return_cash_transaction, :reference_date

  def initialize(user:, context:, return_cash_transaction:, reference_date: nil)
    @user = user
    @context = context
    @return_cash_transaction = return_cash_transaction
    @reference_date = (reference_date || Time.zone.today).to_date
  end

  # @return [Date, nil] the proposed installment date, or nil when there is nothing to place.
  def call
    return nil if unpaid_installments.empty?

    balance_need_date || fallback_date
  end

  private

  # First point of the balance timeline, from the reference month onwards, where the balance
  # turns negative while the pending piggy bank return is not counted.
  def balance_need_date
    excluded_total = 0

    timeline.each do |item|
      if excluded_installment_ids.include?(item[:id])
        excluded_total += item[:price]
        next
      end

      next if (item[:month] <=> reference_month).negative?
      next if item[:balance].nil?

      return clamp_to_reference(item[:date]) if (item[:balance] - excluded_total).negative?
    end

    nil
  end

  # Without a negative point the money is not needed yet: keep the scheduled date while it is
  # still ahead, otherwise start from the reference date.
  def fallback_date
    scheduled = unpaid_installments.map { |installment| installment.date.to_date }.min
    return reference_date if scheduled.blank?

    [ scheduled, reference_date ].max
  end

  def clamp_to_reference(date)
    [ date, reference_date ].max
  end

  def reference_month
    @reference_month ||= [ reference_date.year, reference_date.month ]
  end

  def unpaid_installments
    @unpaid_installments ||= return_cash_transaction.cash_installments.reject(&:paid?).sort_by(&:number)
  end

  def excluded_installment_ids
    @excluded_installment_ids ||= unpaid_installments.map(&:id)
  end

  # Cash installments and budgets share the same running balance, ordered by the order id the
  # balance recalculation assigns.
  def timeline
    @timeline ||= (installment_items + budget_items).sort_by do |item|
      [ item[:order_id].to_i, item[:date], item[:id] ]
    end
  end

  def installment_items
    context.cash_installments.pluck(
      "installments.id", "installments.order_id", "installments.date", "installments.year", "installments.month",
      "installments.price", "installments.balance"
    ).map do |id, order_id, date, year, month, price, balance|
      {
        id: id,
        order_id: order_id,
        date: date.to_date,
        month: [ year, month ],
        price: price.to_i,
        balance: balance
      }
    end
  end

  def budget_items
    context.budgets.pluck(:id, :order_id, :year, :month, :remaining_value, :balance).map do |id, order_id, year, month, remaining_value, balance|
      {
        id: id,
        order_id: order_id,
        date: Date.new(year, month),
        month: [ year, month ],
        price: remaining_value.to_i,
        balance: balance
      }
    end
  end
end
