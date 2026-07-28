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
    target_ids = rows.filter_map do |row|
      row_target_ids = Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq
      row_target_ids.first if row_target_ids.one?
    end.uniq

    targets = scope.context.cash_transactions
                   .includes(:cash_installments, :categories)
                   .where(id: target_ids)
                   .to_a
    preload_projection_target_exchanges(targets)
    targets.index_by(&:id)
  end

  def preload_projection_target_exchanges(targets)
    candidates = targets.select do |target|
      target.exchange_return? && target.cash_installments.none?(&:paid?)
    end
    ActiveRecord::Associations::Preloader.new(records: candidates, associations: :exchanges).call
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
