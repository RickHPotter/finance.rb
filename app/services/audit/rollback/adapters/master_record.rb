# frozen_string_literal: true

class Audit::Rollback::Adapters::MasterRecord < Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = (
    Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES +
      %w[card_transactions_count card_transactions_total cash_transactions_count cash_transactions_total]
  ).freeze

  def dependencies
    @dependencies ||= dependent_identities.map do |dependent_type, dependent_id|
      dependency(record_type: dependent_type, item_id: dependent_id, relationship: :dependent)
    end.uniq(&:key).sort_by(&:key)
  end

  def conflicts
    super.tap do |issues|
      issues << issue(:master_key_taken, conflicting_key: conflicting_record_key) if conflicting_record
    end
  end

  def compensate!(**)
    return super unless action == "recreate"

    record = record_class.new(restore_attributes.merge("id" => item_id))
    record.save!
    record.paper_trail.record_create
    nil
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def context_required?
    false
  end

  def dependent_identities
    allocation_identities + affected_budget_identities
  end

  def allocation_identities
    transitions.filter_map do |candidate|
      next unless candidate.record_type.in?(self.class::ALLOCATION_TYPES)

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      [ candidate.record_type, candidate.item_id ] if states.any? { |state| state[self.class::ALLOCATION_FOREIGN_KEY] == item_id }
    end
  end

  def affected_budget_identities
    budget_ids = transitions.filter_map do |candidate|
      next unless candidate.record_type == self.class::BUDGET_ALLOCATION_TYPE

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      state = states.find { |attributes| attributes[self.class::ALLOCATION_FOREIGN_KEY] == item_id }
      state&.fetch("budget_id", nil)
    end.uniq

    transitions.filter_map do |candidate|
      [ candidate.record_type, candidate.item_id ] if candidate.record_type == "Budget" && candidate.item_id.in?(budget_ids)
    end
  end

  def conflicting_record
    return @conflicting_record if defined?(@conflicting_record)
    return @conflicting_record = nil unless action == "recreate" && before_state.present?

    @conflicting_record = record_class.unscoped.where(
      user_id: before_state["user_id"],
      self.class::NAME_ATTRIBUTE => before_state[self.class::NAME_ATTRIBUTE]
    ).where.not(id: item_id).first
  end

  def conflicting_record_key
    "#{record_type}:#{conflicting_record.id}"
  end
end
