# frozen_string_literal: true

class HealthCheck::Checks::CardExchangeProjection < HealthCheck::Checks::Base
  CHECK_KEY = "card_exchange_projection"

  private

  def audit_counts
    rows = audit_rows
    targets_by_id = HealthCheck::Checks::Repairability.card_projection_targets(scope:, rows:)
    repairable = rows.count do |row|
      HealthCheck::Checks::Repairability.card_projection?(scope:, row:, targets_by_id:)
    end

    {
      affected: rows.size,
      failures: rows.sum { |row| Array(row[:issues]).size },
      warnings: rows.sum { |row| Array(row[:warnings]).size } + rows.count { |row| row[:paid] },
      repairable:,
      read_only: rows.size - repairable,
      unavailable_actions: rows.size - repairable
    }
  end

  def audit_rows
    %w[pending paid].flat_map do |status_filter|
      Logic::CardExchangeProjectionAudit.new(
        current_user: scope.user,
        current_context: scope.context,
        status_filter:
      ).call
    end
  end
end
