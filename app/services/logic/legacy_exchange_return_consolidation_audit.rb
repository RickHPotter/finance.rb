# frozen_string_literal: true

class Logic::LegacyExchangeReturnConsolidationAudit
  def call
    {
      generated_at: Time.current.iso8601,
      candidates_count: candidates.size,
      candidates:
    }
  end

  private

  def candidates
    consolidation_groups.map { |group| serialize_group(group) }
  end

  def consolidation_groups
    grouped_transactions.values.select { |group| group.size > 1 }
  end

  def grouped_transactions
    standalone_exchange_return_transactions.each_with_object({}) do |transaction, result|
      key = consolidation_key_for(transaction)
      next if key.blank?

      result[key] ||= []
      result[key] << transaction
    end
  end

  def standalone_exchange_return_transactions
    CashTransaction.includes(:cash_installments, :exchanges, :categories)
                   .exchange_return
                   .order(:id)
                   .select { |transaction| standalone_exchange_return_candidate?(transaction) }
  end

  def serialize_group(group)
    survivor = group.min_by(&:id)
    payer_entity_transaction = payer_entity_transaction_for(survivor)

    {
      survivor_transaction_id: survivor.id,
      exchange_return_transaction_ids: group.map(&:id),
      user_id: survivor.user_id,
      context_id: survivor.context_id,
      scenario_key: survivor.context.scenario_key,
      payer_entity_transaction_id: payer_entity_transaction&.id,
      desired_installments: desired_installments_for(group),
      current_transactions: group.map { |transaction| serialize_transaction(transaction) }
    }
  end

  def serialize_transaction(transaction)
    {
      id: transaction.id,
      description: transaction.description,
      price: transaction.price,
      date: transaction.date&.to_date&.iso8601,
      month: transaction.month,
      year: transaction.year,
      cash_installments: transaction.cash_installments.order(:number, :date).map do |installment|
        {
          id: installment.id,
          number: installment.number,
          date: installment.date&.to_date&.iso8601,
          month: installment.month,
          year: installment.year,
          price: installment.price,
          paid: installment.paid
        }
      end,
      exchange_ids: transaction.exchanges.monetary.order(:number, :date).pluck(:id)
    }
  end

  def desired_installments_for(group)
    group.flat_map(&:cash_installments)
         .sort_by { |installment| [ installment.date, installment.number, installment.cash_transaction_id, installment.id ] }
         .map.with_index do |installment, index|
      {
        source_transaction_id: installment.cash_transaction_id,
        source_installment_id: installment.id,
        number: index + 1,
        date: installment.date&.to_date&.iso8601,
        month: installment.month,
        year: installment.year,
        price: installment.price,
        paid: installment.paid
      }
    end
  end

  def consolidation_key_for(transaction)
    payer_entity_transaction = payer_entity_transaction_for(transaction)
    return if payer_entity_transaction.blank?

    [
      transaction.user_id,
      transaction.context_id,
      payer_entity_transaction.id
    ].join(":")
  end

  def payer_entity_transaction_for(transaction)
    transaction.exchanges.monetary.order(:id).first&.entity_transaction
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end
end
