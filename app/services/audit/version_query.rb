# frozen_string_literal: true

class Audit::VersionQuery
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
  ITEM_TYPES = Audit::VersionMetadata::ALLOWED_ATTRIBUTES.keys.freeze
  STORED_ITEM_TYPES = ITEM_TYPES.map { |type| type.in?(%w[CashInstallment CardInstallment]) ? "Installment" : type }.uniq.freeze

  class << self
    def authorized_scope(reader)
      reader.admin? ? AuditVersion.all : AuditVersion.where(owner_id: reader.id)
    end

    def record_filter(record_or_type, item_id = nil)
      if record_or_type.respond_to?(:id)
        record_type = record_or_type.class.name
        item_id = record_or_type.id
      else
        record_type = record_or_type.to_s
      end

      normalized_item_filter(record_type).merge("item_id" => item_id)
    end

    def normalized_item_filter(item_type)
      raise ArgumentError, "unsupported audited item type" unless item_type.in?(ITEM_TYPES)

      if item_type.in?(%w[CashInstallment CardInstallment])
        { "item_type" => "Installment", "item_subtype" => item_type }
      else
        { "item_type" => item_type }
      end
    end
  end

  attr_reader :reader, :filters, :order

  def initialize(reader:, filters: {}, order: :descending)
    @reader = reader
    @filters = filters.to_h.stringify_keys
    @order = order
  end

  def call
    paginate(ordered_relation)
  end

  def relation
    apply_filters(self.class.authorized_scope(reader))
  end

  private

  def apply_filters(scope)
    scope = apply_item_filter(scope)
    scope = apply_direct_filters(scope)
    scope = apply_operation_filters(scope)
    apply_date_filters(scope)
  end

  def apply_direct_filters(scope)
    direct_filters = {}
    direct_filters[:item_id] = integer_filter("item_id") if integer_filter("item_id")
    direct_filters[:operation_id] = filters["operation_id"] if valid_uuid?(filters["operation_id"])
    direct_filters[:owner_id] = integer_filter("owner_id") if reader.admin? && integer_filter("owner_id")
    direct_filters[:context_id] = integer_filter("context_id") if integer_filter("context_id")
    direct_filters[:event] = filters["event"] if filters["event"].in?(AuditVersion::EVENTS)
    direct_filters[:mutation_source] = filters["mutation_source"] if filters["mutation_source"].in?(AuditVersion::MUTATION_SOURCES)
    scope.where(direct_filters)
  end

  def apply_item_filter(scope)
    item_type = filters["item_type"]
    return scope if item_type.blank?

    normalized = self.class.normalized_item_filter(item_type)
    normalized["item_subtype"] ||= filters["item_subtype"] if filters["item_subtype"].in?(%w[CashInstallment CardInstallment])
    scope.where(normalized)
  rescue ArgumentError
    scope.none
  end

  def apply_operation_filters(scope)
    operation_filters = {}
    operation_filters[:source] = filters["source"] if filters["source"].in?(AuditOperation::ROOT_SOURCES)
    operation_filters[:actor_id] = integer_filter("actor_id") if integer_filter("actor_id")
    operation_filters[:request_id] = filters["request_id"].to_s.first(255) if filters["request_id"].present?
    return scope if operation_filters.empty?

    scope.joins(:operation).where(audit_operations: operation_filters)
  end

  def apply_date_filters(scope)
    scope = scope.where(created_at: parsed_date("created_from").beginning_of_day..) if parsed_date("created_from")
    scope = scope.where(created_at: ..parsed_date("created_to").end_of_day) if parsed_date("created_to")
    scope
  end

  def ordered_relation
    direction = order == :ascending ? :asc : :desc
    relation.reorder(created_at: direction, id: direction)
  end

  def paginate(scope)
    page_number = [ integer_filter("page").to_i, 1 ].max
    per_page = integer_filter("per_page").to_i
    per_page = DEFAULT_PER_PAGE unless per_page.positive?
    per_page = [ per_page, MAX_PER_PAGE ].min
    total_count = scope.count
    records = scope.offset((page_number - 1) * per_page).limit(per_page).includes(:operation).to_a

    Audit::Page.new(records:, number: page_number, per_page:, total_count:)
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
    value.to_s.match?(UUID_PATTERN)
  end
end
