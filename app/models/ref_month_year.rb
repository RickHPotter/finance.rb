# frozen_string_literal: true

# PORO Class for creating a Reference of MonthYear
class RefMonthYear
  attr_reader :month, :year

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
