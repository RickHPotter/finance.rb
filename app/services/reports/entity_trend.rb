# frozen_string_literal: true

module Reports
  class EntityTrend < AllocationTrend
    def initialize(context:, entity:, query_state:)
      super(context:, anchor: entity, dimension: :entity, query_state:)
    end
  end
end
