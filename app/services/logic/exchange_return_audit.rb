# frozen_string_literal: true

class Logic::ExchangeReturnAudit
  attr_reader :audit_context, :current_user, :status_filter

  def initialize(current_user:, current_context: nil, status_filter: "pending")
    @audit_context = current_context || current_user.ensure_main_context!
    @current_user = current_user
    @status_filter = %w[paid pending].include?(status_filter) ? status_filter : "pending"
  end

  def call
    exchange_returns.filter_map do |cash_transaction|
      build_row(cash_transaction)
    end
  end

  private

  def exchange_returns
    scope = audit_context.cash_transactions
                         .exchange_return
                         .includes(
                           :cash_installments,
                           exchanges: { entity_transaction: [ :entity, { transactable: [ { entity_transactions: :entity } ] } ] }
                         )
                         .order(date: :desc, id: :desc)

    status_filter == "paid" ? scope.where(paid: true) : scope.where(paid: false)
  end

  def build_row(cash_transaction)
    linked_source_rows = linked_source_rows_for(cash_transaction)
    source_allocation_rows = source_allocation_rows_for(linked_source_rows)
    row = base_row_for(cash_transaction, linked_source_rows, source_allocation_rows)
    row[:context] = {
      id: audit_context.id,
      name: audit_context.name,
      scenario_key: audit_context.scenario_key
    }
    row[:paid] = cash_transaction.paid
    row[:status_filter] = status_filter

    row[:issues] = issues_for(row)
    return if row[:issues].empty?

    row
  end

  def linked_source_rows_for(cash_transaction)
    cash_transaction.exchanges
                    .map(&:entity_transaction)
                    .compact
                    .select(&:is_payer?)
                    .uniq
                    .map { |entity_transaction| linked_source_row_for(entity_transaction, cash_transaction.id) }
  end

  def linked_source_row_for(entity_transaction, cash_transaction_id)
    scoped_exchange_total = entity_transaction.exchanges.where(cash_transaction_id:).sum(:price)
    aggregate_exchange_total = entity_transaction.exchanges
                                                 .monetary
                                                 .joins(:cash_transaction)
                                                 .where(cash_transactions: { context_id: audit_context.id })
                                                 .sum(:price)

    {
      entity_transaction_id: entity_transaction.id,
      entity_name: entity_transaction.entity&.entity_name,
      transactable_type: entity_transaction.transactable_type,
      transactable_id: entity_transaction.transactable_id,
      description: entity_transaction.transactable&.description,
      aggregate_total: entity_transaction.price_to_be_returned,
      aggregate_exchange_total:,
      scoped_exchange_total:,
      delta: entity_transaction.price_to_be_returned - aggregate_exchange_total,
      exchanges_count: entity_transaction.exchanges_count,
      transaction_total: entity_transaction.transactable&.price.to_i.abs
    }
  end

  def source_allocation_rows_for(linked_source_rows)
    linked_source_rows
      .group_by { |entry| [ entry[:transactable_type], entry[:transactable_id] ] }
      .values
      .map { |rows| source_allocation_row_for(rows.first) }
      .compact
  end

  def source_allocation_row_for(source_entry)
    transactable = source_entry[:transactable_type].constantize.find_by(id: source_entry[:transactable_id])
    return if transactable.blank?

    allocation_total = transactable.entity_transactions.sum(:price)
    transaction_total = transactable.price.abs
    payer_total = transactable.entity_transactions.sum(:price_to_be_returned)
    has_moi_entity = transactable.entity_transactions.joins(:entity).exists?(entities: { built_in: true })
    missing_amount = transaction_total - allocation_total
    return if missing_amount.zero?

    {
      transactable_type: transactable.class.name,
      transactable_id: transactable.id,
      description: transactable.description,
      transaction_total:,
      allocation_total:,
      payer_total:,
      missing_amount:,
      has_moi_entity:,
      issue_code: !has_moi_entity && missing_amount.positive? ? "missing_moi_allocation" : "entity_allocation_mismatch"
    }
  end

  def base_row_for(cash_transaction, linked_source_rows, source_allocation_rows)
    {
      id: cash_transaction.id,
      description: cash_transaction.description,
      date: cash_transaction.date,
      month_year: cash_transaction.month_year,
      price: cash_transaction.price,
      installments_sum: cash_transaction.cash_installments.sum(:price),
      exchange_rows_sum: cash_transaction.exchanges.sum(:price),
      linked_source_rows: stale_rows_for(linked_source_rows),
      source_allocation_rows:
    }
  end

  def stale_rows_for(linked_source_rows)
    linked_source_rows.reject { |entry| entry[:delta].zero? }.sort_by { |entry| -entry[:delta].abs }
  end

  def issues_for(row)
    issues = []
    issues << "installments_total_mismatch" if row[:price] != row[:installments_sum]
    issues << "exchange_rows_total_mismatch" if row[:price] != row[:exchange_rows_sum]
    issues << "stale_linked_source_rows" if row[:linked_source_rows].present?
    issues << "source_allocation_mismatch" if row[:source_allocation_rows].present?
    issues
  end
end
