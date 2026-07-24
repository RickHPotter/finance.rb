# frozen_string_literal: true

module HealthCheck::Checks::Repairability
  SUPPORTED_ALLOCATION_ISSUES = %w[entity_allocation_mismatch missing_moi_allocation].freeze

  module_function

  def exchange_return_allocation?(row)
    return false if row[:paid]

    Array(row[:source_allocation_rows]).any? do |allocation|
      allocation[:entity_transaction_id].present? &&
        allocation[:issue_code].in?(SUPPORTED_ALLOCATION_ISSUES) &&
        HealthCheck::Repairs::ExchangeReturnAllocationPlanner.strategies_for(allocation).any?
    end
  end

  def card_projection?(scope:, row:, targets_by_id: nil)
    return false if row[:paid]

    target_ids = Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq
    return false unless target_ids.one?

    target = if targets_by_id
               targets_by_id[target_ids.first]
             else
               scope.context.cash_transactions.includes(:cash_installments, :categories, :exchanges).find_by(id: target_ids.first)
             end
    return false unless safe_projection_target?(target)

    projection_shape_fixable?(row, target)
  end

  def card_projection_targets(scope:, rows:)
    target_ids = rows.flat_map do |row|
      Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }
    end.uniq

    scope.context.cash_transactions
         .includes(:cash_installments, :categories, :exchanges)
         .where(id: target_ids)
         .index_by(&:id)
  end

  def safe_projection_target?(target)
    target&.exchange_return? &&
      target.cash_installments.none?(&:paid?) &&
      target.exchanges.any? { |exchange| exchange.card_bound? && exchange.monetary? }
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
