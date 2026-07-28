# frozen_string_literal: true

class HealthCheck::Checks::DetailsBase
  attr_reader :filters, :scope

  def initialize(scope:, filters: {})
    @scope = scope
    @filters = filters.to_h.stringify_keys
  end

  def call
    evaluated_at = Time.current
    rows = ordered_rows

    HealthCheck::Page.from(
      records: rows,
      page: filters["page"],
      per_page: filters["per_page"],
      filters: normalized_filters,
      evaluated_at:
    )
  end

  private

  def rows
    raise NotImplementedError
  end

  def ordered_rows
    rows.sort_by { |row| sort_key(row) }.reverse
  end

  def sort_key(row)
    [ sortable_time(row[:date]), stable_id(row) ]
  end

  def sortable_time(value)
    value&.to_time&.to_f || 0
  end

  def stable_id(row)
    row[:id].to_i
  end

  def normalized_filters
    { "per_page" => filters["per_page"] }.merge(provider_filters)
  end

  def provider_filters
    {}
  end

  def status_filter
    filters["status_filter"].in?(%w[paid pending]) ? filters["status_filter"] : "pending"
  end

  def issue_filter(allowed)
    filters["issue_filter"].presence_in(allowed)
  end
end
