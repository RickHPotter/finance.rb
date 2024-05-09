# frozen_string_literal: true

# Shared functionality for models that have month and year attributes.
module HasMonthYear
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :check_date, if: -> { respond_to?(:date) && date.nil? }
    before_validation :set_month_year, if: -> { errors.none? && respond_to?(:month) }
  end

  # @public_instance_methods ..................................................

  # Gets the formatted `month` and `year` string.
  #
  # @see {RefMonthYear#month_year}.
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
  # @return [Integer].
  #
  def day
    date&.day
  end

  # Fetches the date based on a set `date`, with a given number of days, months and years forwards or backwards.
  #
  # @param date [Date] The date to start from.
  # @param day [Integer] The amount of days to add/subtract.
  # @param month [Integer] The amount of months to add/subtract.
  # @param year [Integer] The amount of years to add/subtract.
  #
  # @return [Date].
  #
  def next_date(date: Date.current, days: Date.current.day, months: 0, years: 0)
    Date.new(date.year, date.month) + (days - 1).days + months.month + years.years
  end

  # Fetches the last day of given `month` and `year`.
  #
  # @return [Date].
  #
  def end_of_month
    Date.new(year, month).at_end_of_month
  end

  # @protected_instance_methods ...............................................

  protected

  # Checks if `date` is nil when self responds to `date`. If so, adds an error.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def check_date
    errors.add(:date, :blank)
  end

  # Sets `month` and `year` based on self's `date` or `user_card.current_due_date`.
  #
  # @note This is a method that is called before_validation.
  #
  # @see {#set_month_year_card_transaction}.
  # @see {#set_month_year_installment}.
  #
  # @return [void].
  #
  def set_month_year
    if instance_of? CardTransaction
      set_month_year_card_transaction
    elsif instance_of? Installment
      set_month_year_installment
    else
      self.month = date&.month
      self.year = date&.year
    end
  end

  # Sets `month` and `year` based on the first `installment#money_transaction_date` or self's `date` or `user_card.current_due_date`.
  #
  # @return [void].
  #
  def set_month_year_card_transaction
    new_date = installments.first&.money_transaction_date || date
    self.month = new_date.month || user_card.current_closing_date.month
    self.year = new_date.year || user_card.current_closing_date.year
  end

  # Sets `month` and `year` based on `money_transaction_date`.
  #
  # @return [void].
  #
  def set_month_year_installment
    new_date = money_transaction_date
    self.month = new_date.month
    self.year = new_date.year
  end
end
