# frozen_string_literal: true

module Reports
  class CategoryTrend < AllocationTrend
    def initialize(context:, category:, query_state:)
      super(context:, anchor: category, dimension: :category, query_state:)
    end
  end
end
