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
    @year = year.to_s.rjust(4, "20").to_i
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
    I18n.l(Date.new(@year, @month), format: "%b <%y>").upcase
  end

  # Initialises a new {RefMonthYear} instance from a string.
  #
  # @param month_year [String] The month (e.g., "May" or "NOV") and year (e.g., "2023" or "23" or even "- 23").
  #
  # @example Create a new RefMonthYear instance:
  #   ref_month_year = RefMonthYear.from_string("NOV <24>")
  #
  # @note The `MONTH` of `month_year` is expected to be in either `MONTHS_ABBR` or `MONTHS_FULL`.
  #
  # @return [RefMonthYear] A new instance of {RefMonthYear}.
  #
  def self.from_string(month_year)
    month, year = month_year.split

    month = [ *MONTHS_ABBR, *MONTHS_FULL ].map(&:parameterize).index(month.parameterize) + 1
    year = year.gsub(/[^\d.-]+/, "").rjust(4, "20").to_i

    RefMonthYear.new(month, year.to_i)
  end

  # Gets the span of dates according to a `pivot date` respecting the boundary of `max_date`.
  #
  # @param pivot_date [Date] The pivot date, usually the `Date.current`.
  # @param max_date [Date] The maximum date, the boundary of the span.
  # @param interval [Integer] The interval, amount of months in the span.
  #
  # @example Get the span of dates:
  #   RefMonthYear.get_span(Date.new(2023, 1, 1), Date.new(2024, 1, 1), 6)
  #   # => [Thu, 01 Sep 2022, Tue, 28 Feb 2023]
  #
  #   RefMonthYear.get_span(Date.new(2024, 1, 1), Date.new(2024, 1, 1), 6)
  #   # => [Tue, 01 Aug 2023, Wed, 31 Jan 2024]
  #
  #   RefMonthYear.get_span(Date.new(2025, 1, 1), Date.new(2024, 1, 1), 6)
  #   # => [Tue, 01 Aug 2023, Wed, 31 Jan 2024]
  #
  # @return [Array<Date>] The span of dates.
  #
  def self.get_span(pivot_date, max_date, interval)
    if pivot_date.beginning_of_month >= max_date.beginning_of_month
      [ max_date.prev_month(interval - 1).beginning_of_month, max_date.end_of_month ]
    else
      [ pivot_date.prev_month(interval - 2).beginning_of_month, pivot_date.next_month(1).end_of_month ]
    end
  end
end
