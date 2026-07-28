# frozen_string_literal: true

class HealthCheck::Page
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  attr_reader :evaluated_at, :filters, :number, :per_page, :records, :total_count

  def self.from(records:, page:, per_page:, filters: {}, evaluated_at: Time.current)
    requested_page = [ Integer(page, exception: false).to_i, 1 ].max
    page_size = Integer(per_page, exception: false).to_i
    page_size = DEFAULT_PER_PAGE unless page_size.positive?
    page_size = [ page_size, MAX_PER_PAGE ].min
    total_pages = [ (records.size.to_f / page_size).ceil, 1 ].max
    page_number = requested_page <= total_pages ? requested_page : 1
    offset = (page_number - 1) * page_size

    new(
      records: records.slice(offset, page_size) || [],
      pagination: {
        number: page_number,
        per_page: page_size,
        total_count: records.size
      },
      filters: filters.to_h.merge(per_page: page_size),
      evaluated_at:
    )
  end

  def initialize(records:, pagination:, filters:, evaluated_at:)
    @records = Array(records).freeze
    @number = pagination.fetch(:number)
    @per_page = pagination.fetch(:per_page)
    @total_count = pagination.fetch(:total_count)
    @filters = filters.to_h.stringify_keys.compact_blank.freeze
    @evaluated_at = evaluated_at
    freeze
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
