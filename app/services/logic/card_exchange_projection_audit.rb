# frozen_string_literal: true

class Logic::CardExchangeProjectionAudit
  attr_reader :audit_context, :current_user, :status_filter

  def initialize(current_user:, current_context: nil, status_filter: "pending")
    @audit_context = current_context || current_user.ensure_main_context!
    @current_user = current_user
    @status_filter = %w[paid pending].include?(status_filter) ? status_filter : "pending"
  end

  def call
    card_transactions.filter_map do |card_transaction|
      build_row(card_transaction)
    end
  end

  private

  def card_transactions
    scope = audit_context.card_transactions
                         .includes(:card_installments, entity_transactions: [ :entity, { exchanges: :cash_transaction } ])
                         .order(date: :desc, id: :desc)

    status_filter == "paid" ? scope.where(paid: true) : scope.where(paid: false)
  end

  def build_row(card_transaction)
    payer_entity_transactions = card_transaction.entity_transactions.select(&:is_payer?)
    return if payer_entity_transactions.blank?

    expected_rows = expected_rows_for(card_transaction)
    actual_rows = actual_rows_for(payer_entity_transactions)
    row = base_row_for(card_transaction, payer_entity_transactions, expected_rows, actual_rows)

    row[:issues] = issues_for(row)
    row[:warnings] = warnings_for(row)
    return if row[:issues].empty? && row[:warnings].empty?

    row
  end

  def base_row_for(card_transaction, payer_entity_transactions, expected_rows, actual_rows)
    {
      id: card_transaction.id,
      description: card_transaction.description,
      date: card_transaction.date,
      month_year: card_transaction.month_year,
      context: {
        id: audit_context.id,
        name: audit_context.name,
        scenario_key: audit_context.scenario_key
      },
      paid: card_transaction.paid,
      status_filter:,
      card_price: card_transaction.price,
      expected_total: expected_rows.sum { |entry| entry[:price] },
      actual_total: actual_rows.sum { |entry| entry[:price] },
      payer_declared_total: payer_entity_transactions.sum(&:price_to_be_returned),
      allocation_total: card_transaction.entity_transactions.sum(&:price),
      expected_rows:,
      actual_rows:,
      payer_entity_transaction_ids: payer_entity_transactions.map(&:id),
      allocation_issue: allocation_issue_for(card_transaction),
      warnings: []
    }
  end

  def expected_rows_for(card_transaction)
    card_transaction.card_installments.order(:number, :date).map do |installment|
      {
        number: installment.number,
        month: installment.month,
        year: installment.year,
        price: installment.price.abs,
        signature: signature_for(month: installment.month, year: installment.year, price: installment.price.abs)
      }
    end
  end

  def actual_rows_for(entity_transactions)
    entity_transactions
      .flat_map(&:exchanges)
      .select(&:monetary?)
      .select { |exchange| exchange.cash_transaction&.context_id == audit_context.id }
      .sort_by { |exchange| [ exchange.number, exchange.date, exchange.entity_transaction_id ] }
      .map do |exchange|
      {
        id: exchange.id,
        entity_transaction_id: exchange.entity_transaction_id,
        entity_name: exchange.entity_transaction.entity&.entity_name,
        cash_transaction_id: exchange.cash_transaction_id,
        number: exchange.number,
        month: exchange.month,
        year: exchange.year,
        price: exchange.price,
        signature: signature_for(month: exchange.month, year: exchange.year, price: exchange.price)
      }
    end
  end

  def allocation_issue_for(card_transaction)
    transaction_total = card_transaction.price.abs
    entity_transactions = card_transaction.entity_transactions.to_a
    allocation_total = entity_transactions.sum(&:price)
    return if allocation_total == transaction_total
    return if source_allocation_explained_by_return_percentages?(entity_transactions, transaction_total)

    has_moi_entity = entity_transactions.any? { |entity_transaction| entity_transaction.entity&.built_in? }

    {
      transactable_type: "CardTransaction",
      transactable_id: card_transaction.id,
      description: card_transaction.description,
      transaction_total:,
      allocation_total:,
      payer_total: entity_transactions.sum(&:price_to_be_returned),
      missing_amount: transaction_total - allocation_total,
      has_moi_entity:,
      issue_code: !has_moi_entity && transaction_total > allocation_total ? "missing_moi_allocation" : "entity_allocation_mismatch"
    }
  end

  def issues_for(row)
    issues = []
    issues << "source_allocation_mismatch" if row[:allocation_issue].present?
    issues << "payer_exchange_total_mismatch" if row[:actual_total] != row[:payer_declared_total]
    issues
  end

  def warnings_for(row)
    warnings = []
    return warnings if missing_self_share_allocation?(row)
    return warnings if split_allocation_valid?(row)

    warnings << "projection_shape_mismatch" if row[:expected_total] != row[:actual_total] &&
                                               row[:expected_rows].map { |entry| entry[:signature] }.sort != row[:actual_rows].map { |entry| entry[:signature] }.sort
    warnings << "duplicate_projection_buckets" if row[:expected_total] != row[:actual_total] && duplicate_buckets_in(row[:actual_rows]).present?
    warnings
  end

  def split_allocation_valid?(row)
    row[:allocation_total] == row[:card_price].abs
  end

  def missing_self_share_allocation?(row)
    row[:allocation_issue].present? && row[:allocation_issue][:missing_amount].positive?
  end

  def duplicate_buckets_in(rows)
    rows.group_by { |entry| [ entry[:month], entry[:year] ] }.select { |_bucket, entries| entries.size > 1 }
  end

  def source_allocation_explained_by_return_percentages?(entity_transactions, transaction_total)
    implied_total = entity_transactions.select(&:is_payer?).sum do |entity_transaction|
      percentage = entity_transaction.loan_return_percentage.to_d
      return false unless percentage.positive?

      ((entity_transaction.price_to_be_returned.to_i.abs.to_d * 100) / percentage).round
    end

    implied_total == transaction_total.to_i.abs
  end

  def signature_for(month:, year:, price:)
    [ month, year, price ]
  end
end
