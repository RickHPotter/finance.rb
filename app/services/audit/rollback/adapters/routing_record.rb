# frozen_string_literal: true

class Audit::Rollback::Adapters::RoutingRecord < Audit::Rollback::Adapters::Base
  def dependencies
    @dependencies ||= (dependent_identities.map do |dependent_type, dependent_id|
      dependency(record_type: dependent_type, item_id: dependent_id, relationship: :dependent)
    end + replacement_dependencies).uniq(&:key).sort_by(&:key)
  end

  def conflicts
    super.tap do |issues|
      issues << issue(:routing_key_taken, conflicting_key: conflicting_record_key) if conflicting_record && replacement_transition.nil?
    end
  end

  private

  def context_required?
    false
  end

  def dependent_identities
    (live_dependent_identities + historical_dependent_identities).uniq.sort
  end

  def historical_dependent_identities
    transitions.filter_map do |candidate|
      next unless candidate.record_type.in?(dependent_types)

      states = [ candidate.before_state, candidate.expected_after_state ].compact
      [ candidate.record_type, candidate.item_id ] if states.any? { |state| state[routing_foreign_key] == item_id }
    end
  end

  def replacement_dependencies
    return [] unless replacement_transition&.action == "destroy"

    [ dependency(record_type:, item_id: replacement_transition.item_id, relationship: :dependent) ]
  end

  def conflicting_record
    return @conflicting_record if defined?(@conflicting_record)
    return @conflicting_record = nil if action == "destroy" || before_state.blank?

    @conflicting_record = conflict_scope.where.not(id: item_id).first
  end

  def conflicting_record_key
    "#{record_type}:#{conflicting_record.id}"
  end

  def replacement_transition
    return unless conflicting_record

    transitions.find { |candidate| candidate.record_type == record_type && candidate.item_id == conflicting_record.id }
  end
end
