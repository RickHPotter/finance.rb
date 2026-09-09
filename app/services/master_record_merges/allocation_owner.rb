# frozen_string_literal: true

class MasterRecordMerges::AllocationOwner
  Identity = Data.define(:record, :user_id, :context_id, :supported?)

  class << self
    def resolve(row)
      owner = owner_for(row)
      supported = owner.present? && owner.respond_to?(:user_id) && owner.respond_to?(:context_id)

      Identity.new(
        record: owner,
        user_id: supported ? owner.user_id : nil,
        context_id: supported ? owner.context_id : nil,
        supported?: supported
      )
    end

    private

    def owner_for(row)
      return row.transactable if row.is_a?(CategoryTransaction) || row.is_a?(EntityTransaction)
      return row.budget if row.is_a?(BudgetCategory) || row.is_a?(BudgetEntity)

      nil
    end
  end
end
