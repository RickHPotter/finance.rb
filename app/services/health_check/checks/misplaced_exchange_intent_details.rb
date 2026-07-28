# frozen_string_literal: true

class HealthCheck::Checks::MisplacedExchangeIntentDetails < HealthCheck::Checks::DetailsBase
  private

  def rows
    Logic::MisplacedLoanExchangeAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      connected_user_id: scope.connected_user&.id
    ).call.map do |row|
      owner = row[:source_user_id] == scope.user.id
      row.merge(
        health_check: {
          repairable: owner,
          unavailable_reason: ("owner_only" unless owner),
          preview_actions: owner ? [ { finding_id: row[:source_id] } ] : []
        }.compact
      )
    end
  end

  def sort_key(row)
    [ sortable_time(row[:latest_message_at] || row[:date]), stable_id(row) ]
  end

  def stable_id(row)
    row[:source_id].to_i
  end
end
