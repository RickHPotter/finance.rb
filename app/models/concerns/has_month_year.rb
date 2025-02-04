# frozen_string_literal: true

# Shared functionality for models that have month and year attributes.
module HasMonthYear
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_date, on: :create
    before_validation :check_date, if: -> { respond_to?(:date) && date.nil? }
    before_validation :set_month_year, if: -> { errors.none? && respond_to?(:month) }
  end

  # @public_instance_methods ..................................................

  # Gets the formatted `month` and `year` string. In case `month` or `year` is nil, it will be set first.
  #
  # @see {RefMonthYear#month_year}.
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>".
  #
  def month_year
    set_month_year if month.nil? || year.nil?

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
  def next_date(date: Date.current, days: date.day, months: 0, years: 0)
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

  def set_date
    self.date = card_transaction.date&.next_month(number - 1) if instance_of?(CardInstallment)
    self.date = cash_transaction.date&.next_month(number - 1) if instance_of?(CashInstallment)
  end

  # Checks if `date` is nil when self responds to `date`. If so, adds an error.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def check_date
    errors.add(:date, :blank)
  end

  # Sets `month` and `year` based on self's `cash_transaction_date` or `date`.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_month_year
    return if defined?(imported) && imported
    return if defined?(card_transaction) && card_transaction.imported

    if instance_of?(CardTransaction) || instance_of?(CardInstallment)
      self.month = cash_transaction_date.month
      self.year  = cash_transaction_date.year
    else
      self.month ||= date.month
      self.year  ||= date.year
    end
  end
end
