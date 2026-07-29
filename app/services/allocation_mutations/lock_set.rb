# frozen_string_literal: true

class AllocationMutations::LockSet
  attr_reader :selection, :action

  def initialize(selection:, action:)
    @selection = selection
    @action = action
  end

  def call
    lock_context
    lock_requested_allocation_records
    owners = selection.owners(lock: true)
    lock_allocation_rows
    owners.each(&:reload)
  end

  private

  def lock_context
    Context.where(id: selection.context.id).lock.pick(:id)
  end

  def lock_requested_allocation_records
    ids = [ action.source_id, action.destination_id ].compact.uniq.sort
    scope = action.allocation_type == :category ? selection.actor.categories : selection.actor.entities
    scope.where(id: ids).order(:id).lock.load
  end

  def lock_allocation_rows
    if selection.owner_type == "Budget"
      BudgetCategory.where(budget_id: selection.owner_ids).order(:id).lock.load
      BudgetEntity.where(budget_id: selection.owner_ids).order(:id).lock.load
      return
    end

    CategoryTransaction.where(transactable_type: selection.owner_type, transactable_id: selection.owner_ids).order(:id).lock.load
    EntityTransaction.where(transactable_type: selection.owner_type, transactable_id: selection.owner_ids).order(:id).lock.load
  end
end
