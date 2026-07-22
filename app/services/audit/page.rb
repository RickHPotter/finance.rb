# frozen_string_literal: true

class Audit::Page
  attr_reader :records, :number, :per_page, :total_count

  def initialize(records:, number:, per_page:, total_count:)
    @records = records
    @number = number
    @per_page = per_page
    @total_count = total_count
  end

  def total_pages
    return 1 if total_count.zero?

    (total_count.to_f / per_page).ceil
  end

  def previous_page
    number - 1 if number > 1
  end

  def next_page
    number + 1 if number < total_pages
  end
end
