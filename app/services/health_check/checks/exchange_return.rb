# frozen_string_literal: true

class HealthCheck::Checks::ExchangeReturn < HealthCheck::Checks::Base
  CHECK_KEY = "exchange_return"

  private

  def audit_counts
    rows = audit_rows
    repairable = rows.count { |row| HealthCheck::Checks::Repairability.exchange_return_allocation?(row) }

    {
      affected: rows.size,
      failures: rows.sum { |row| Array(row[:issues]).size },
      warnings: rows.count { |row| row[:paid] },
      repairable:,
      read_only: rows.size - repairable,
      unavailable_actions: rows.size - repairable
    }
  end

  def audit_rows
    %w[pending paid].flat_map do |status_filter|
      Logic::ExchangeReturnAudit.new(
        current_user: scope.user,
        current_context: scope.context,
        status_filter:
      ).call
    end
  end
end
