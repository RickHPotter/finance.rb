# frozen_string_literal: true

AllocationMutations::Impact = Data.define(
  :owner_type,
  :owner_id,
  :context_id,
  :category_ids_before,
  :category_ids_after,
  :entity_ids_before,
  :entity_ids_after,
  :reference_months
) do
  class << self
    def build(owner:, category_ids_before: nil, category_ids_after: nil, entity_ids_before: nil, entity_ids_after: nil)
      adapter = AllocationMutations::OwnerAdapter.for(owner)

      new(
        owner_type: adapter.owner_type,
        owner_id: adapter.id,
        context_id: adapter.context.id,
        category_ids_before: category_ids_before || adapter.category_ids,
        category_ids_after: category_ids_after || adapter.category_ids,
        entity_ids_before: entity_ids_before || adapter.entity_ids,
        entity_ids_after: entity_ids_after || adapter.entity_ids,
        reference_months: adapter.reference_months
      )
    end
  end

  def initialize(**attributes)
    super(
      owner_type: attributes.fetch(:owner_type).to_s,
      owner_id: normalize_id(attributes.fetch(:owner_id)),
      context_id: normalize_id(attributes.fetch(:context_id)),
      category_ids_before: normalize_ids(attributes.fetch(:category_ids_before)),
      category_ids_after: normalize_ids(attributes.fetch(:category_ids_after)),
      entity_ids_before: normalize_ids(attributes.fetch(:entity_ids_before)),
      entity_ids_after: normalize_ids(attributes.fetch(:entity_ids_after)),
      reference_months: Array(attributes.fetch(:reference_months)).uniq.sort.freeze
    )
  end

  def affected_category_ids
    (category_ids_before | category_ids_after).sort.freeze
  end

  def affected_entity_ids
    (entity_ids_before | entity_ids_after).sort.freeze
  end

  def category_changed?
    category_ids_before != category_ids_after
  end

  def entity_changed?
    entity_ids_before != entity_ids_after
  end

  private

  def normalize_id(value)
    Integer(value).tap { |id| raise ArgumentError, "impact identifiers must be positive" unless id.positive? }
  end

  def normalize_ids(values)
    Array(values).map { |value| normalize_id(value) }.uniq.sort.freeze
  end
end
