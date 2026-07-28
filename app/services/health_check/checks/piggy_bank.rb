# frozen_string_literal: true

class HealthCheck::Checks::PiggyBank < HealthCheck::Checks::Base
  CHECK_KEY = "piggy_bank"

  private

  def audit_counts
    rows = Logic::PiggyBankAudit.new(current_user: scope.user, current_context: scope.context).call

    {
      affected: rows.size,
      failures: rows.sum { |row| Array(row[:issues]).size },
      warnings: 0,
      repairable: 0,
      read_only: rows.size,
      unavailable_actions: rows.size
    }
  end
end
