# frozen_string_literal: true

# PORO Class for creating a Reference of MonthYear.
class RefMonthYear
  attr_reader :month, :year

  # Initialises a new {RefMonthYear} instance.
  #
  # @param month [Integer] The month (1-12).
  # @param year [Integer] The year (e.g., 2023).
  #
  # @example Create a new RefMonthYear instance:
  #   ref_month_year = RefMonthYear.new(5, 2023)
  #
  # @note The `month` is expected to be an integer between 1 and 12.
  # @note The `year` can be in either 2 or 4 digits.
  #
  # @return [RefMonthYear] A new instance of {RefMonthYear}.
  #
  def initialize(month, year)
    @month = month
    @year = year % 100
  end

  # Gets the formatted `month` and `year` string.
  #
  # @example Get the `month` and year for a CardTransaction:
  #   card_transaction = CardTransaction.new(month: 5, year: 2023)
  #   card_transaction.month_year
  #   # => "May <23>"
  #
  # @return [String] Formatted `month` and `year` string in the format "MONTH <YEAR>".
  #
  def month_year
    "#{MONTHS_ABBR[@month - 1].upcase} <#{@year}>"
  end
end
