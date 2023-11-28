# frozen_string_literal: true

# PORO Class for creating a Reference of MonthYear
class RefMonthYear
  attr_reader :month, :year

  # Initialize a new RefMonthYear instance.
  #
  # @param month [Integer] The month (1-12).
  # @param year [Integer] The year (e.g., 2023).
  #
  # @return [RefMonthYear] A new instance of RefMonthYear.
  #
  # @example Create a new RefMonthYear instance
  #   ref_month_year = RefMonthYear.new(5, 2023)
  #
  # @note The month is expected to be an integer between 1 and 12.
  #
  def initialize(month, year)
    @month = month
    @year = year % 100
  end

  # Get the formatted month and year string.
  #
  # This method returns a formatted string representing the month and year
  # using the RefMonthYear class.
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>"
  #
  # @example Get the month and year for a CardTransaction
  #   card_transaction = CardTransaction.new(month: 5, year: 2023)
  #   card_transaction.month_year
  #   # => "May <23>"
  #
  # @note The method uses the RefMonthYear class to format the month and year.
  #
  def month_year
    "#{MONTHS_ABBR[@month - 1].upcase} <#{@year}>"
  end
end
