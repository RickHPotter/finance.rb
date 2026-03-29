# frozen_string_literal: true

class Logic::StandaloneExchangeIntegrityAudit
  attr_reader :ids

  def initialize(ids: nil)
    @ids = Array(ids).compact_blank.map(&:to_i)
  end

  def call
    {
      generated_at: Time.current.iso8601,
      candidates_count: candidates.size,
      candidates:
    }
  end

  private

  def candidates
    @candidates ||= target_transactions.filter_map do |transaction|
      issues = issues_for(transaction)
      next if issues.empty?

      serialize_candidate(transaction, issues)
    end
  end

  def target_transactions
    scope = CashTransaction.includes(:cash_installments, exchanges: :entity_transaction).exchange_return.order(:id)
    scope = scope.where(id: ids) if ids.present?

    scope.select { |transaction| standalone_exchange_return_candidate?(transaction) }
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end

  def issues_for(transaction)
    issues = []
    exchanges = standalone_monetary_exchanges_for(transaction)
    entity_transaction = payer_entity_transaction_for(transaction)

    issues << "multiple_payer_entity_transactions" if payer_entity_transactions_for(transaction).size > 1
    issues << "cash_installments_count_mismatch" if transaction.cash_installments.size != exchanges.size
    issues << "cash_installments_count_column_mismatch" if transaction.cash_installments_count != transaction.cash_installments.size

    if entity_transaction.present?
      issues << "entity_transaction_price_to_be_returned_mismatch" if entity_transaction.price_to_be_returned != exchanges.sum(&:price)
      issues << "entity_transaction_exchanges_count_mismatch" if entity_transaction.exchanges_count != exchanges.size
    end

    issues << "exchange_row_exchanges_count_mismatch" if exchanges.any? { |exchange| exchange.exchanges_count != exchanges.size }
    issues
  end

  def serialize_candidate(transaction, issues)
    exchanges = standalone_monetary_exchanges_for(transaction)
    entity_transaction = payer_entity_transaction_for(transaction)

    {
      exchange_return_transaction_id: transaction.id,
      user_id: transaction.user_id,
      context_id: transaction.context_id,
      entity_transaction_id: entity_transaction&.id,
      issues:,
      current: {
        cash_installments_count: transaction.cash_installments.size,
        cash_installments_count_column: transaction.cash_installments_count,
        exchanges_count: exchanges.size,
        exchanges_sum_price: exchanges.sum(&:price),
        entity_transaction_price: entity_transaction&.price,
        entity_transaction_price_to_be_returned: entity_transaction&.price_to_be_returned,
        entity_transaction_exchanges_count: entity_transaction&.exchanges_count
      },
      desired: {
        cash_installments_count: exchanges.size,
        entity_transaction_price: entity_transaction&.price == entity_transaction&.price_to_be_returned ? exchanges.sum(&:price) : entity_transaction&.price,
        entity_transaction_price_to_be_returned: exchanges.sum(&:price),
        entity_transaction_exchanges_count: exchanges.size
      },
      exchanges: serialize_rows(exchanges),
      cash_installments: serialize_rows(transaction.cash_installments.order(:number, :date))
    }
  end

  def serialize_rows(rows)
    rows.map do |row|
      {
        id: row.id,
        number: row.number,
        date: row.date&.to_date&.iso8601,
        month: row.month,
        year: row.year,
        price: row.price
      }
    end
  end

  def standalone_monetary_exchanges_for(transaction)
    transaction.exchanges.monetary.standalone.order(:date, :number, :id).to_a
  end

  def payer_entity_transactions_for(transaction)
    standalone_monetary_exchanges_for(transaction).map(&:entity_transaction).uniq(&:id)
  end

  def payer_entity_transaction_for(transaction)
    payer_entity_transactions_for(transaction).one? ? payer_entity_transactions_for(transaction).first : nil
  end
end
