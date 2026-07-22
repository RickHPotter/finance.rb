# frozen_string_literal: true

class Audit::OperationQuery
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  attr_reader :reader, :filters

  def initialize(reader:, filters: {})
    @reader = reader
    @filters = filters.to_h.stringify_keys
  end

  def call
    scope = relation.reorder(created_at: :desc, id: :desc)
    page_number = [ integer_filter("page").to_i, 1 ].max
    per_page = integer_filter("per_page").to_i
    per_page = DEFAULT_PER_PAGE unless per_page.positive?
    per_page = [ per_page, MAX_PER_PAGE ].min

    Audit::Page.new(
      records: scope.offset((page_number - 1) * per_page).limit(per_page).to_a,
      number: page_number,
      per_page:,
      total_count: scope.count
    )
  end

  def relation
    apply_operation_filters(authorized_scope)
  end

  def find(id)
    relation.find_by(id:)
  end

  private

  def authorized_scope
    return AuditOperation.all if reader.admin?

    AuditOperation.where(id: Audit::VersionQuery.authorized_scope(reader).select(:operation_id))
  end

  def apply_operation_filters(scope)
    scope = scope.where(id: filters["operation_id"]) if valid_uuid?(filters["operation_id"])
    scope = scope.where(actor_id: integer_filter("actor_id")) if integer_filter("actor_id")
    scope = scope.where(context_id: integer_filter("context_id")) if integer_filter("context_id")
    scope = scope.where(source: filters["source"]) if filters["source"].in?(AuditOperation::ROOT_SOURCES)
    scope = scope.where(request_id: filters["request_id"].to_s.first(255)) if filters["request_id"].present?
    scope = apply_version_filters(scope)
    apply_date_filters(scope)
  end

  def apply_version_filters(scope)
    version_filters = filters.slice("item_type", "item_subtype", "item_id", "owner_id", "event", "mutation_source")
    return scope if version_filters.values.all?(&:blank?)

    versions = Audit::VersionQuery.new(reader:, filters: version_filters).relation
    scope.where(id: versions.select(:operation_id))
  end

  def apply_date_filters(scope)
    scope = scope.where(created_at: parsed_date("created_from").beginning_of_day..) if parsed_date("created_from")
    scope = scope.where(created_at: ..parsed_date("created_to").end_of_day) if parsed_date("created_to")
    scope
  end

  def integer_filter(name)
    Integer(filters[name], exception: false)
  end

  def parsed_date(name)
    Date.iso8601(filters[name].to_s) if filters[name].present?
  rescue Date::Error
    nil
  end

  def valid_uuid?(value)
    value.to_s.match?(Audit::VersionQuery::UUID_PATTERN)
  end
end
