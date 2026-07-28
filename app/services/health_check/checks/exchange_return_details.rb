# frozen_string_literal: true

class HealthCheck::Checks::ExchangeReturnDetails < HealthCheck::Checks::DetailsBase
  ISSUE_CODES = %w[
    installments_total_mismatch
    exchange_rows_total_mismatch
    stale_linked_source_rows
    source_allocation_mismatch
    message_replay_payload_mismatch
    card_bound_bill_projection_mismatch
  ].freeze

  private

  def rows
    Logic::ExchangeReturnAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      issue_filter: issue_filter(ISSUE_CODES),
      status_filter:
    ).call.map do |row|
      preview_actions = Array(row[:source_allocation_rows]).flat_map do |allocation|
        HealthCheck::Repairs::ExchangeReturnAllocationPlanner.strategies_for(allocation).map do |strategy|
          {
            finding_id: allocation[:entity_transaction_id],
            strategy:
          }
        end
      end
      row.merge(
        health_check: {
          repairable: HealthCheck::Checks::Repairability.exchange_return_allocation?(row),
          unavailable_reason: unavailable_reason(row),
          preview_actions:
        }
      )
    end
  end

  def unavailable_reason(row)
    return "paid_history" if row[:paid]
    return if HealthCheck::Checks::Repairability.exchange_return_allocation?(row)

    "diagnostic_only"
  end

  def provider_filters
    {
      "status_filter" => status_filter,
      "issue_filter" => issue_filter(ISSUE_CODES)
    }
  end
end
