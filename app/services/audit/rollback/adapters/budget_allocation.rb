# frozen_string_literal: true

class Audit::Rollback::Adapters::BudgetAllocation < Audit::Rollback::Adapters::Base
  RECALCULATIONS = %w[budget_remaining_value cash_balance].freeze

  def support_issues
    budget_ids.empty? ? [ issue(:missing_parent_identity) ] : []
  end

  def dependencies
    @dependencies ||= budget_ids.map do |budget_id|
      dependency(record_type: "Budget", item_id: budget_id, relationship: :parent)
    end
  end

  def conflicts
    super.tap do |issues|
      issues << issue(:allocation_key_taken, conflicting_key: conflicting_record_key) if conflicting_record
    end
  end

  def recalculations
    RECALCULATIONS
  end

  private

  def budget_ids
    @budget_ids ||= [ before_state, expected_after_state, current_state ].compact.filter_map { |state| state["budget_id"] }.uniq.sort
  end

  def dependency_available?(dependency)
    Budget.unscoped.exists?(id: dependency.item_id)
  end

  def conflicting_record
    return @conflicting_record if defined?(@conflicting_record)
    return @conflicting_record = nil if action == "destroy" || before_state.blank?

    @conflicting_record = record_class.unscoped.where(
      budget_id: before_state["budget_id"],
      allocation_foreign_key => before_state[allocation_foreign_key]
    ).where.not(id: item_id).first
  end

  def conflicting_record_key
    "#{record_type}:#{conflicting_record.id}"
  end

  def allocation_foreign_key
    self.class::ALLOCATION_FOREIGN_KEY
  end
end
