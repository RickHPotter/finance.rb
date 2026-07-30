# frozen_string_literal: true

class AllocationMutations::OwnerSelection
  OWNER_TYPES = {
    "Budget" => :budgets,
    "CardTransaction" => :card_transactions,
    "CashTransaction" => :cash_transactions
  }.freeze
  MAXIMUM_OWNERS = 500

  attr_reader :actor, :context, :owner_type, :owner_ids, :selected_row_count

  def initialize(actor:, context:, owner_type:, owner_ids:, selected_row_count: nil)
    @actor = actor
    @context = context
    @owner_type = owner_type.to_s
    @owner_ids = normalize_ids(owner_ids)
    @selected_row_count = normalize_selected_row_count(selected_row_count)

    validate!
  end

  def owners(lock: false)
    relation = context.public_send(OWNER_TYPES.fetch(owner_type)).where(id: owner_ids).order(:id)
    relation = relation.lock if lock
    records = relation.to_a
    raise ActiveRecord::RecordNotFound, "allocation owners are outside the current context" unless records.map(&:id) == owner_ids

    records
  end

  def to_h
    {
      "owner_type" => owner_type,
      "owner_ids" => owner_ids,
      "selected_row_count" => selected_row_count
    }.freeze
  end

  private

  def validate!
    raise ArgumentError, "actor and context are required" if actor.blank? || context.blank?
    raise ArgumentError, "context does not belong to actor" unless context.user_id == actor.id
    raise ArgumentError, "unsupported allocation owner type: #{owner_type}" unless OWNER_TYPES.key?(owner_type)
    raise ArgumentError, "at least one allocation owner is required" if owner_ids.empty?
    raise ArgumentError, "allocation owner selection is too large" if owner_ids.size > MAXIMUM_OWNERS
    raise ArgumentError, "selected row count cannot be smaller than the unique owner count" if selected_row_count < owner_ids.size
  end

  def normalize_ids(values)
    raw_values = Array(values).compact_blank
    ids = raw_values.map { |value| Integer(value, exception: false) }
    raise ArgumentError, "allocation owner identifiers must be positive integers" if ids.any? { |id| id.blank? || !id.positive? }

    ids.uniq.sort.freeze
  end

  def normalize_selected_row_count(value)
    return owner_ids.size if value.blank?

    Integer(value).tap { |count| raise ArgumentError, "selected row count must be positive" unless count.positive? }
  end
end
