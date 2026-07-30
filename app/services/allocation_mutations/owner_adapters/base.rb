# frozen_string_literal: true

class AllocationMutations::OwnerAdapters::Base
  attr_reader :owner

  delegate :id, :user, :context, to: :owner

  def initialize(owner)
    @owner = owner
  end

  def owner_type
    owner.class.base_class.name
  end

  def category_ids
    category_allocations.filter_map(&:category_id).uniq.sort
  end

  def entity_ids
    entity_allocations.filter_map(&:entity_id).uniq.sort
  end

  def reference_months
    raise NotImplementedError
  end

  def category_allocations
    raise NotImplementedError
  end

  def entity_allocations
    raise NotImplementedError
  end
end
