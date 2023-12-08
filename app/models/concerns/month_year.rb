# frozen_string_literal: true

# Shared functionality for month and year models.
module MonthYear
  extend ActiveSupport::Concern

  included do
    before_validation :set_month_year, on: :create
  end

  # @public_instance_methods ..................................................
  # Get the formatted month and year string.
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>"
  #
  # @note This method internally uses the RefMonthYear#month_year.
  #
  def month_year
    month ||= date.month
    year ||= date.year
    RefMonthYear.new(month, year).month_year
  end

  # Fetch the day of given date
  #
  # @return [Integer]
  #
  def day
    date&.day
  end

  # Fetch the last day of given MonthYear
  #
  # @return [Date]
  #
  def end_of_month
    Date.new(year, month).at_end_of_month
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets Month and Year from Date
  #
  # @return [void]
  #
  def set_month_year
    # FIXME: Card Transactions dont work this way,
    #        remember to shift year when month is 12
    self.month ||= date&.month
    self.year ||= date&.year
  end
end
