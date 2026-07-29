# frozen_string_literal: true

class AllocationMutations::OwnerAdapter
  class UnsupportedOwner < ArgumentError; end

  class << self
    def for(owner)
      case owner
      when CashTransaction, CardTransaction
        AllocationMutations::OwnerAdapters::Transaction.new(owner)
      when Budget
        AllocationMutations::OwnerAdapters::Budget.new(owner)
      else
        raise UnsupportedOwner, "unsupported allocation owner: #{owner.class.name}"
      end
    end
  end
end
