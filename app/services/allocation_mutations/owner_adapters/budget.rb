# frozen_string_literal: true

class AllocationMutations::OwnerAdapters::Budget < AllocationMutations::OwnerAdapters::Base
  def category_allocations
    owner.budget_categories
  end

  def entity_allocations
    owner.budget_entities
  end

  def reference_months
    return [].freeze if owner.year.blank? || owner.month.blank?

    [ Date.new(owner.year, owner.month, 1) ].freeze
  rescue Date::Error
    [].freeze
  end
end
