# frozen_string_literal: true

class HealthCheck::Checks::MisplacedExchangeIntent < HealthCheck::Checks::Base
  CHECK_KEY = "misplaced_exchange_intent"

  private

  def audit_counts
    rows = Logic::MisplacedLoanExchangeAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      connected_user_id: scope.connected_user&.id
    ).call
    repairable = rows.count { |row| row[:source_user_id] == scope.user.id }
    affected_messages = rows.flat_map { |row| Array(row[:message_ids]) }.uniq.size

    {
      affected: rows.size + affected_messages,
      failures: rows.size,
      warnings: 0,
      repairable:,
      read_only: rows.size - repairable,
      unavailable_actions: rows.size - repairable
    }
  end
end
