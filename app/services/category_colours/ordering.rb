# frozen_string_literal: true

class CategoryColours::Ordering
  ALWAYS_FIRST_BUILT_IN_NAMES = [ "FAILED LEND/BORROW RETURN" ].freeze

  class << self
    def call(categories)
      unique_categories(categories)
        .each_with_index
        .sort_by { |category, index| [ precedence(category), index ] }
        .map(&:first)
    end

    def from_allocations(allocations)
      call(Array(allocations).sort_by(&:id).filter_map(&:category))
    end

    private

    def unique_categories(categories)
      Array(categories).compact.uniq { |category| [ category.class.name, category.id || category.object_id ] }
    end

    def precedence(category)
      return 0 if category.built_in? && category.category_name.in?(ALWAYS_FIRST_BUILT_IN_NAMES)
      return 1 if category.built_in?

      2
    end
  end
end
