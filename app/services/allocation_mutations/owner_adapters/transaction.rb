# frozen_string_literal: true

class AllocationMutations::OwnerAdapters::Transaction < AllocationMutations::OwnerAdapters::Base
  def category_allocations
    owner.category_transactions
  end

  def entity_allocations
    owner.entity_transactions
  end

  def reference_months
    owner.installments.filter_map do |installment|
      next if installment.year.blank? || installment.month.blank?

      Date.new(installment.year, installment.month, 1)
    rescue Date::Error
      nil
    end.uniq.sort.freeze
  end
end
