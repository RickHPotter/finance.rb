# frozen_string_literal: true

# Shared functionality for month and year models.
module MonthYear
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_month_year
  end

  # @public_instance_methods ..................................................
  # Gets the formatted month and year string.
  #
  # @see {RefMonthYear#month_year}
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>".
  #
  def month_year
    month = self.month || date.month
    year = self.year || date.year
    RefMonthYear.new(month, year).month_year
  end

  # Fetches the day of set attribute `date`.
  #
  # @return [Integer]
  #
  def day
    date&.day
  end

  # Fetches the date based on a set date, with a given number of days,
  # months and years forwards or backwards.
  #
  # @param date [Date] The date to start from.
  # @param day [Integer] The amount of days to add/subtract.
  # @param month [Integer] The amount of months to add/subtract.
  # @param year [Integer] The amount of years to add/subtract.
  #
  # @return [Date]
  #
  def next_date(date: Date.current, days: Date.current.day, months: 0, years: 0)
    Date.new(date.year, date.month) + (days - 1).days + months.month + years.years
  end

  # Fetches the last day of given MonthYear.
  #
  # @return [Date]
  #
  def end_of_month
    Date.new(year, month).at_end_of_month
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets Month and Year from based on `date` or `user_card.current_due_date`.
  #
  # @return [void]
  #
  def set_month_year
    return if errors.any?
    return unless respond_to?(:month)

    if instance_of? CardTransaction
      set_month_year_card_transaction
    elsif instance_of? Installment
      set_month_year_installment
    else
      self.month = date&.month
      self.year = date&.year
    end
  end

  def set_month_year_card_transaction
    new_date = installments.first&.money_transaction_date || date
    self.month = new_date.month || user_card.current_closing_date.month
    self.year = new_date.year || user_card.current_closing_date.year
  end

  def set_month_year_installment
    new_date = (money_transaction_date || card_transaction.date) + (number - 1).months
    self.month = new_date.month
    self.year = new_date.year
  end
end
