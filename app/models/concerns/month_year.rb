# frozen_string_literal: true

# Shared functionality for month and year models.
module MonthYear
  extend ActiveSupport::Concern

  # @public_instance_methods ..................................................
  # Get the formatted month and year string.
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>"
  #
  # @note This method internally uses the RefMonthYear#month_year.
  #
  def month_year
    RefMonthYear.new(month, year).month_year
  end
end
