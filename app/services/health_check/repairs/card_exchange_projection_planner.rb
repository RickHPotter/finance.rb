# frozen_string_literal: true

class HealthCheck::Repairs::CardExchangeProjectionPlanner < HealthCheck::Repairs::BasePlanner
  def call
    card_transaction = scoped_card_transaction
    return paid_history_result(card_transaction) if card_transaction.paid?

    row = live_row
    return read_only("finding_not_current", references: references_for(card_transaction)) if row.blank?

    target = projection_target(row)
    return unsafe_target_result(card_transaction, row) if target.blank?

    changes = projection_changes(row, target)
    return read_only("diagnostic_only", references: references_for(card_transaction, row:, target:)) if changes.empty?

    previewable(
      changes:,
      references: references_for(card_transaction, row:, target:),
      warnings: unresolved_warnings(row),
      paid_history: {
        affected: false,
        target_installments: target.cash_installments.size,
        paid_target_installments: 0
      }
    )
  end

  private

  def scoped_card_transaction
    @scoped_card_transaction ||= scope.context.card_transactions.includes(:card_installments).find(finding_id)
  end

  def live_row
    @live_row ||= Logic::CardExchangeProjectionAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      status_filter: "pending"
    ).call.find { |row| row[:id].to_i == finding_id }
  end

  def projection_target(row)
    target_ids = Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq
    return unless target_ids.one?

    target = scope.context.cash_transactions
                  .includes(:cash_installments, :categories, exchanges: { entity_transaction: :entity })
                  .find_by(id: target_ids.first)
    return unless HealthCheck::Checks::Repairability.safe_projection_target?(target)

    target
  end

  def projection_changes(row, target)
    expected_by_number = Array(row[:expected_rows]).index_by { |expected| expected[:number] }
    [ *bucket_changes(row, target, expected_by_number), total_change(row, target) ].compact
  end

  def bucket_changes(row, target, expected_by_number)
    Array(row[:actual_rows]).filter_map do |actual|
      expected = expected_by_number[actual[:number]]
      next if expected.blank? || [ actual[:month], actual[:year] ] == [ expected[:month], expected[:year] ]

      bucket_change(actual, expected, target)
    end
  end

  def total_change(row, target)
    projected_total = Array(row[:actual_rows]).sum { |actual| actual[:price].to_i }
    return if target.price.to_i == projected_total

    change(
      record_type: "CashTransaction",
      record_id: target.id,
      attribute: "price",
      before: target.price,
      after: projected_total,
      metadata: { role: "projection_total" }
    )
  end

  def bucket_change(actual, expected, target)
    change(
      record_type: "Exchange",
      record_id: actual[:id],
      attribute: "billing_bucket",
      before: { month: actual[:month], year: actual[:year] },
      after: { month: expected[:month], year: expected[:year] },
      metadata: {
        number: actual[:number],
        cash_transaction_id: target.id,
        entity_transaction_id: actual[:entity_transaction_id]
      }
    )
  end

  def unsafe_target_result(card_transaction, row)
    target_ids = Array(row[:actual_rows]).filter_map { |actual| actual[:cash_transaction_id] }.uniq
    reason = target_ids.many? ? "ambiguous_projection" : "diagnostic_only"
    paid = target_ids.any? do |target_id|
      scope.context.cash_transactions.find_by(id: target_id)&.cash_installments&.any?(&:paid?)
    end
    reason = "paid_history" if paid

    read_only(
      reason,
      references: references_for(card_transaction, row:),
      paid_history: { affected: paid }
    )
  end

  def paid_history_result(card_transaction)
    read_only(
      "paid_history",
      references: references_for(card_transaction),
      paid_history: { affected: true, source_paid: true }
    )
  end

  def unresolved_warnings(row)
    (Array(row[:issues]) + Array(row[:warnings])).uniq
  end

  def references_for(card_transaction, row: nil, target: nil)
    [
      {
        type: "CardTransaction",
        id: card_transaction.id,
        role: "projection_source",
        installment_ids: card_transaction.card_installments.map(&:id)
      },
      {
        type: "CashTransaction",
        id: target&.id,
        ids: Array(row&.dig(:actual_rows)).filter_map { |actual| actual[:cash_transaction_id] }.uniq,
        role: "projection_target",
        exchange_ids: Array(row&.dig(:actual_rows)).filter_map { |actual| actual[:id] }
      }
    ]
  end
end
