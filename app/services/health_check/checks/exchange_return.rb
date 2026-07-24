# frozen_string_literal: true

class HealthCheck::Checks::ExchangeReturn < HealthCheck::Checks::Base
  CHECK_KEY = "exchange_return"
  SUPPORTED_ALLOCATION_ISSUES = %w[entity_allocation_mismatch missing_moi_allocation].freeze

  private

  def audit_counts
    rows = audit_rows
    repairable = rows.count { |row| repairable_allocation?(row) }

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

  def repairable_allocation?(row)
    return false if row[:paid]

    Array(row[:source_allocation_rows]).any? do |allocation|
      allocation[:entity_transaction_id].present? &&
        allocation[:issue_code].in?(SUPPORTED_ALLOCATION_ISSUES) &&
        (allocation[:calculated_loan_return_percentage].present? || allocation[:calculated_price].present?)
    end
  end
end
