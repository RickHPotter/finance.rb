# frozen_string_literal: true

class Audit::Rollback::Adapters::Allocation < Audit::Rollback::Adapters::Base
  def support_issues
    parent_identities.empty? ? [ issue(:missing_parent_identity) ] : []
  end

  def dependencies
    @dependencies ||= parent_dependencies + replacement_dependencies
  end

  def conflicts
    super.tap do |issues|
      issues << issue(:allocation_key_taken, conflicting_key: conflicting_record_key) if conflicting_record && replacement_transition.nil?
    end
  end

  private

  def parent_dependencies
    parent_identities.map do |record_type, parent_id|
      dependency(record_type:, item_id: parent_id, relationship: :parent)
    end.sort_by(&:key)
  end

  def replacement_dependencies
    return [] unless replacement_transition&.action == "destroy"

    [
      dependency(
        record_type: replacement_transition.record_type,
        item_id: replacement_transition.item_id,
        relationship: :dependent
      )
    ]
  end

  def parent_identities
    @parent_identities ||= [ before_state, expected_after_state, current_state ].compact.filter_map do |state|
      record_type = state["transactable_type"]
      record_id = state["transactable_id"]
      [ record_type, record_id ] if record_type.present? && record_id.present?
    end.uniq
  end

  def dependency_available?(dependency)
    dependency.record_type.constantize.unscoped.exists?(id: dependency.item_id)
  rescue NameError
    false
  end

  def conflicting_record
    return @conflicting_record if defined?(@conflicting_record)
    return @conflicting_record = nil if action == "destroy" || target_state.blank?

    @conflicting_record = record_class.unscoped.find_by(
      allocation_foreign_key => target_state[allocation_foreign_key],
      transactable_type: target_state["transactable_type"],
      transactable_id: target_state["transactable_id"]
    )
    @conflicting_record = nil if @conflicting_record&.id == item_id
    @conflicting_record
  end

  def conflicting_record_key
    "#{record_type}:#{conflicting_record.id}"
  end

  def replacement_transition
    return unless conflicting_record

    transitions.find { |candidate| candidate.record_type == record_type && candidate.item_id == conflicting_record.id }
  end

  def target_state
    before_state
  end

  def allocation_foreign_key
    self.class::ALLOCATION_FOREIGN_KEY
  end
end
