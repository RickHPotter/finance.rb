# frozen_string_literal: true

class HealthCheck::Checks::CardExchangeProjectionDetails < HealthCheck::Checks::DetailsBase
  ISSUE_CODES = %w[
    source_allocation_mismatch
    payer_exchange_total_mismatch
    projection_shape_mismatch
    duplicate_projection_buckets
  ].freeze

  private

  def rows
    audit_rows = Logic::CardExchangeProjectionAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      status_filter:
    ).call
    targets_by_id = HealthCheck::Checks::Repairability.card_projection_targets(scope:, rows: audit_rows)

    audit_rows.filter_map do |row|
      next unless selected_issue.blank? || (Array(row[:issues]) + Array(row[:warnings])).include?(selected_issue)

      repairable = HealthCheck::Checks::Repairability.card_projection?(scope:, row:, targets_by_id:)
      row.merge(
        health_check: {
          repairable:,
          unavailable_reason: unavailable_reason(row, repairable:),
          preview_actions: repairable ? [ { finding_id: row[:id] } ] : []
        }
      )
    end
  end

  def selected_issue
    @selected_issue ||= issue_filter(ISSUE_CODES)
  end

  def unavailable_reason(row, repairable:)
    return if repairable
    return "paid_history" if row[:paid]
    return "ambiguous_projection" if Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq.many?

    "diagnostic_only"
  end

  def provider_filters
    {
      "status_filter" => status_filter,
      "issue_filter" => selected_issue
    }
  end
end
