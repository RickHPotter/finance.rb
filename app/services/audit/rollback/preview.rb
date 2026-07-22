# frozen_string_literal: true

class Audit::Rollback::Preview
  STATES = %w[previewable read_only conflicted prohibited].freeze

  attr_reader :operation, :actor, :rows, :global_issues, :digest, :apply_token

  def initialize(operation:, actor:)
    @operation = operation
    @actor = actor
    transitions = Audit::Rollback::NetState.new(versions: operation.audit_versions).call
    operation_keys = transitions.map(&:key)
    @rows = transitions.map do |transition|
      adapter = Audit::Rollback::Registry.build(transition:, operation_keys:)
      Audit::Rollback::PreviewRow.new(transition:, adapter:)
    end
    @global_issues = build_global_issues
    @digest = Digest::SHA256.hexdigest(Audit::Rollback::State.canonical_json(digest_payload))
    @apply_token = Audit::Rollback::PreviewToken.generate(operation_id: operation.id, digest:, actor_id: actor.id)
  end

  def state
    return "read_only" if global_issues.present? || rows.any? { |row| row.support_issues.present? }
    return "prohibited" if rows.any? { |row| row.prohibitions.present? }
    return "conflicted" if rows.any? { |row| row.conflicts.present? }

    "previewable"
  end

  def affected_owner_ids
    rows.map(&:owner_id).compact.uniq.sort
  end

  def affected_context_ids
    rows.map(&:context_id).compact.uniq.sort
  end

  def confirmation_required?
    rows.any? { |row| row.requirements.present? }
  end

  def digest_payload
    {
      operation: {
        id: operation.id,
        actor_id: operation.actor_id,
        context_id: operation.context_id,
        request_id: operation.request_id,
        source: operation.source,
        result: operation.result,
        parent_operation_id: operation.parent_operation_id,
        metadata: operation.metadata
      },
      global_issues: global_issues.map(&:to_h),
      rows: rows.map(&:digest_payload)
    }
  end

  private

  def build_global_issues
    issues = []
    issues << issue(:operation_has_no_versions) if rows.empty?
    issues << issue(:target_not_committed) unless operation.result_committed?
    issues << issue(:rollback_target_not_supported) if operation.source_rollback? || operation.rollback_of_operation_id.present?
    issues
  end

  def issue(code, details = {})
    Audit::Rollback::Issue.new(code:, details:)
  end
end
