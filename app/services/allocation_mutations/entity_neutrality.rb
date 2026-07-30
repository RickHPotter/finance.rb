# frozen_string_literal: true

class AllocationMutations::EntityNeutrality
  class << self
    def neutral?(allocation)
      reasons(allocation).empty?
    end

    def reasons(allocation)
      [
        (:payer if allocation.is_payer?),
        (:price if allocation.price.to_i.nonzero?),
        (:return if allocation.price_to_be_returned.to_i.nonzero?),
        (:exchanges if exchanges?(allocation))
      ].compact.freeze
    end

    private

    def exchanges?(allocation)
      return allocation.exchanges.any? if allocation.exchanges.loaded? || allocation.new_record?

      allocation.exchanges.exists?
    end
  end
end
