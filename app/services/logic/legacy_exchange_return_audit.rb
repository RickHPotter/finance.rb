# frozen_string_literal: true

class Logic::LegacyExchangeReturnAudit
  def call
    {
      generated_at: Time.current.iso8601,
      candidates_count: candidates.size,
      candidates:
    }
  end

  private

  def candidates
    legacy_exchange_return_transactions.map { |transaction| serialize_candidate(transaction) }
  end

  def legacy_exchange_return_transactions
    CashTransaction.includes(:cash_installments, :exchanges, :categories)
                   .exchange_return
                   .order(:id)
                   .select do |transaction|
      standalone_exchange_return_candidate?(transaction) && needs_projection_sync?(transaction)
    end
  end

  def serialize_candidate(transaction)
    counterpart = transaction.counterpart_shared_return_transaction

    {
      exchange_return_transaction_id: transaction.id,
      user_id: transaction.user_id,
      context_id: transaction.context_id,
      scenario_key: transaction.context.scenario_key,
      description: transaction.description,
      exchange_bound_types: transaction.exchanges.monetary.distinct.pluck(:bound_type),
      counterpart_transaction_id: counterpart&.id,
      counterpart_user_id: counterpart&.user_id,
      current_installments: current_installment_rows(transaction),
      exchange_rows: current_exchange_rows(transaction),
      desired_exchange_rows: desired_exchange_rows(transaction)
    }
  end

  def needs_projection_sync?(transaction)
    current_exchange_rows(transaction) != desired_exchange_rows(transaction)
  end

  def desired_exchange_rows(transaction)
    current_installment_rows(transaction).map do |row|
      row.slice(:number, :date, :month, :year, :price)
    end
  end

  def current_installment_rows(transaction)
    transaction.cash_installments.order(:number, :date).map do |installment|
      {
        number: installment.number,
        date: installment.date&.to_date&.iso8601,
        month: installment.month,
        year: installment.year,
        price: installment.price,
        paid: installment.paid
      }
    end
  end

  def current_exchange_rows(transaction)
    transaction.exchanges.monetary.order(:number, :date).map do |exchange|
      {
        number: exchange.number,
        date: exchange.date&.to_date&.iso8601,
        month: exchange.month,
        year: exchange.year,
        price: exchange.price
      }
    end
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end
end
