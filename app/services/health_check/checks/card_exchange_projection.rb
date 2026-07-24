# frozen_string_literal: true

class HealthCheck::Checks::CardExchangeProjection < HealthCheck::Checks::Base
  CHECK_KEY = "card_exchange_projection"

  private

  def audit_counts
    rows = audit_rows
    repairable = rows.count { |row| repairable_projection?(row) }

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

  def repairable_projection?(row)
    return false if row[:paid]

    target_ids = Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq
    return false unless target_ids.one?

    target = scope.context.cash_transactions
                  .includes(:cash_installments, :exchanges)
                  .find_by(id: target_ids.first)
    return false unless safe_projection_target?(target)

    projection_shape_fixable?(row, target)
  end

  def safe_projection_target?(target)
    target&.exchange_return? &&
      target.cash_installments.none?(&:paid?) &&
      target.exchanges.card_bound.monetary.exists?
  end

  def projection_shape_fixable?(row, target)
    actual_rows = Array(row[:actual_rows])
    expected_by_number = Array(row[:expected_rows]).index_by { |expected| expected[:number] }
    bucket_mismatch = actual_rows.any? do |actual|
      expected = expected_by_number[actual[:number]]
      expected.present? && (actual[:month] != expected[:month] || actual[:year] != expected[:year])
    end

    bucket_mismatch || target.price != actual_rows.sum { |actual| actual[:price] }
  end
end
