# frozen_string_literal: true

class Audit::Rollback::Adapters::Base
  DERIVED_ATTRIBUTES = %w[created_at updated_at].freeze

  attr_reader :transition, :operation_keys, :transitions

  delegate :record_type, :item_id, :owner_id, :context_id, :before_state, :expected_after_state, :action, to: :transition

  def initialize(transition:, operation_keys:, transitions: [])
    @transition = transition
    @operation_keys = operation_keys
    @transitions = transitions
  end

  def support_issues
    []
  end

  def prohibitions
    @prohibitions ||= [].tap do |issues|
      issues << issue(:inconsistent_version_ownership) unless transition.ownership_consistent?
      issues << issue(:unknown_owner) unless User.exists?(id: owner_id)
      issues << issue(:unknown_context) unless Context.exists?(id: context_id, user_id: owner_id)
    end
  end

  def conflicts
    @conflicts ||= begin
      issues = state_conflicts
      issues << issue(:current_ownership_changed) if current_record.present? && current_ownership_mismatch?
      add_dependency_conflicts(issues)
      issues
    end
  end

  def requirements
    paid_history? && action != "none" ? [ issue(:historical_correction_confirmation) ] : []
  end

  def dependencies
    []
  end

  def recalculations
    []
  end

  def current_state
    return @current_state if defined?(@current_state)
    return @current_state = nil if current_record.nil?

    @current_state = Audit::Rollback::State.normalize(record_type, current_record.attributes.slice(*comparable_attributes))
  end

  def live_record
    current_record
  end

  def restore_attributes
    Audit::Rollback::Attributes.for(self)
  end

  def differences
    return @differences if defined?(@differences)
    return @differences = {} if expected_after_state.nil? || current_state.nil?

    @differences = comparable_attributes.each_with_object({}) do |attribute, result|
      expected = expected_after_state[attribute]
      current = current_state[attribute]
      result[attribute] = { "expected" => expected, "current" => current } unless expected == current
    end
  end

  def comparison_attributes
    (comparable_attributes + differences.keys).uniq.sort
  end

  private

  def current_record
    return @current_record if defined?(@current_record)

    @current_record = find_current_record
  end

  def find_current_record
    record_class.unscoped.find_by(id: item_id)
  end

  def record_class
    record_type.constantize
  end

  def comparable_attributes
    @comparable_attributes ||= ((before_state&.keys || []) | (expected_after_state&.keys || [])) - ignored_attributes
  end

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def state_conflicts
    if expected_after_state.nil?
      current_record.present? ? [ issue(:expected_record_absent) ] : []
    elsif current_record.nil?
      [ issue(:expected_record_missing) ]
    elsif differences.present?
      [ issue(:current_state_changed, attributes: differences.keys.sort) ]
    else
      []
    end
  end

  def current_ownership_mismatch?
    ownership = Audit::OwnershipResolver.resolve!(current_record)
    ownership.owner_id != owner_id || ownership.context_id != context_id
  rescue Audit::OwnershipResolver::UnsupportedRecordError, Audit::OwnershipResolver::UnresolvableOwnershipError
    true
  end

  def paid_history?
    states = [ before_state, expected_after_state, current_state ].compact
    states.any? { |state| ActiveModel::Type::Boolean.new.cast(state["paid"]) }
  end

  def dependency(record_type:, item_id:, relationship:)
    Audit::Rollback::Dependency.new(
      record_type:,
      item_id:,
      relationship:,
      included: "#{record_type}:#{item_id}".in?(operation_keys)
    )
  end

  def dependency_available?(_dependency)
    true
  end

  def add_dependency_conflicts(issues)
    orphaned_dependencies = dependencies.select { |dependency| dependency.relationship == "dependent" && !dependency.included }
    missing_parents = dependencies.select { |dependency| dependency.relationship == "parent" && !dependency.included && !dependency_available?(dependency) }
    issues << issue(:later_dependencies, dependencies: orphaned_dependencies.map(&:key).sort) if action == "destroy" && orphaned_dependencies.present?
    issues << issue(:missing_parent_dependency, dependencies: missing_parents.map(&:key).sort) if missing_parents.present?
  end

  def issue(code, details = {})
    Audit::Rollback::Issue.new(code:, details:)
  end
end
