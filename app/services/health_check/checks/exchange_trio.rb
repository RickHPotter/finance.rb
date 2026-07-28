# frozen_string_literal: true

class HealthCheck::Checks::ExchangeTrio < HealthCheck::Checks::Base
  CHECK_KEY = "exchange_trio"

  private

  def audit_counts
    rows = projected_rows
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:).call
    affected_rows = rows.reject { |row| row[:status] == "done" }
    repairable = reference_audit[:supported_count]

    {
      affected: affected_rows.size,
      failures: affected_rows.sum { |row| Array(row[:issues]).size },
      warnings: affected_rows.sum { |row| Array(row[:warnings]).size },
      repairable:,
      read_only: [ affected_rows.size - repairable, 0 ].max,
      unavailable_actions: reference_audit[:skipped_count] + affected_rows.count { |row| row[:proposed_changes].blank? }
    }
  end

  def projected_rows
    rows = Logic::ExchangeTrioAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      connected_user_id: scope.connected_user&.id
    ).call

    Logic::ExchangeAuditSelectionProjector.new(rows:).call
  end
end
