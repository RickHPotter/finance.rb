# frozen_string_literal: true

class Audit::Rollback::Adapters::Entity < Audit::Rollback::Adapters::MasterRecord
  ALLOCATION_TYPES = %w[EntityTransaction BudgetEntity].freeze
  ALLOCATION_FOREIGN_KEY = "entity_id"
  BUDGET_ALLOCATION_TYPE = "BudgetEntity"
  NAME_ATTRIBUTE = "entity_name"
  RECALCULATIONS = %w[entity_transaction_totals cash_balance].freeze

  def recalculations
    RECALCULATIONS
  end

  def dependencies
    (super + friendship_dependencies).uniq(&:key).sort_by(&:key)
  end

  private

  def friendship_dependencies
    friendship_ids.map do |friendship_id|
      dependency(record_type: "Friendship", item_id: friendship_id, relationship: :parent)
    end
  end

  def friendship_ids
    [ before_state, expected_after_state, current_state ].compact.filter_map { |state| state["friendship_id"] }.uniq.sort
  end

  def dependency_available?(dependency)
    return Friendship.exists?(id: dependency.item_id) if dependency.record_type == "Friendship"

    super
  end
end
