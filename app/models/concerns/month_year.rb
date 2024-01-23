# frozen_string_literal: true

# Shared functionality for month and year models.
module MonthYear
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_month_year, on: :create
  end

  # @public_instance_methods ..................................................
  # Gets the formatted month and year string.
  #
  # @see {RefMonthYear#month_year}
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>".
  #
  def month_year
    month ||= date.month
    year ||= date.year
    RefMonthYear.new(month, year).month_year
  end

  # Fetches the day of set attribute `date`.
  #
  # @return [Integer]
  #
  def day
    date&.day
  end

  # Fetches the date in the next month given a certain day.
  #
  # @param day [Integer] The day of the next month.
  #
  # @return [Date]
  #
  def next_month_this(day: Date.current.day)
    today = Date.current
    Date.new(today.year, today.month, day) + 1.month
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
    return unless respond_to?(:month)

    if instance_of?(CardTransaction)
      self.month ||= user_card.current_due_date.month
      self.year ||= user_card.current_due_date.year
    else
      self.month ||= date&.month
      self.year ||= date&.year
    end
  end
end
