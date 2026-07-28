# frozen_string_literal: true

class Audit::Rollback::PreviewRow
  attr_reader :transition, :adapter

  delegate :record_type, :item_id, :owner_id, :context_id, :before_state, :expected_after_state, :action, :event_sequence, :key, to: :transition

  def initialize(transition:, adapter:)
    @transition = transition
    @adapter = adapter
  end

  def support_issues
    return @support_issues ||= adapter.support_issues if adapter

    @support_issues ||= [ issue(:unsupported_record_type, record_type:) ]
  end

  def prohibitions
    @prohibitions ||= adapter ? adapter.prohibitions : []
  end

  def conflicts
    @conflicts ||= adapter ? adapter.conflicts : []
  end

  def requirements
    @requirements ||= adapter ? adapter.requirements : []
  end

  def dependencies
    @dependencies ||= adapter ? adapter.dependencies : []
  end

  def recalculations
    adapter ? adapter.recalculations : []
  end

  def current_state
    return @current_state if defined?(@current_state)

    @current_state = adapter&.current_state
  end

  def comparison_attributes
    adapter ? adapter.comparison_attributes : ((before_state&.keys || []) | (expected_after_state&.keys || [])).sort
  end

  def digest_payload
    {
      key:,
      owner_id:,
      context_id:,
      event_sequence:,
      action:,
      before_state:,
      expected_after_state:,
      current_state:,
      support_issues: serialize(support_issues),
      prohibitions: serialize(prohibitions),
      conflicts: serialize(conflicts),
      requirements: serialize(requirements),
      dependencies: dependencies.map(&:to_h),
      recalculations:
    }
  end

  private

  def serialize(issues)
    issues.map(&:to_h)
  end

  def issue(code, details = {})
    Audit::Rollback::Issue.new(code:, details:)
  end
end
