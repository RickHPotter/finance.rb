# frozen_string_literal: true

class Logic::LegacyExchangeReturnRunner
  attr_reader :ids, :dry_run

  def initialize(ids: nil, dry_run: true)
    @ids = Array(ids).compact_blank.map(&:to_i)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      processed_count: target_transactions.size,
      updated_count: updates.size,
      skipped_count: skipped.size,
      updates:,
      skipped:
    }
  end

  private

  def updates
    @updates ||= run[:updates]
  end

  def skipped
    @skipped ||= run[:skipped]
  end

  def run
    target_transactions.each_with_object({ updates: [], skipped: [] }) do |transaction, result|
      unless transaction.exchanges.monetary.exists?
        result[:skipped] << { exchange_return_transaction_id: transaction.id, reason: "no_monetary_exchanges" }
        next
      end

      unless standalone_exchange_return_candidate?(transaction)
        result[:skipped] << {
          exchange_return_transaction_id: transaction.id,
          reason: "non_standalone_exchange_return",
          exchange_bound_types: transaction.exchanges.monetary.distinct.pluck(:bound_type)
        }
        next
      end

      desired_rows = desired_exchange_rows(transaction)

      if desired_rows.blank?
        result[:skipped] << { exchange_return_transaction_id: transaction.id, reason: "desired_exchange_rows_blank" }
        next
      end

      next result[:updates] << serialize_update(transaction, desired_rows) if dry_run

      sync_exchanges_from_installments!(transaction, desired_rows)
      result[:updates] << serialize_update(transaction.reload, desired_rows)
    end
  end

  def target_transactions
    scope = CashTransaction.includes(:cash_installments, :exchanges, :categories).exchange_return.order(:id)
    scope = scope.where(id: ids) if ids.present?

    scope.select do |transaction|
      transaction.exchanges.monetary.present? && standalone_exchange_return_candidate?(transaction) && needs_projection_sync?(transaction)
    end
  end

  def sync_exchanges_from_installments!(transaction, desired_rows)
    transaction.with_lock do
      existing_exchanges = exchange_rows_for(transaction)
      entity_transaction = exchange_entity_transaction(existing_exchanges)
      bound_type = exchange_bound_type(existing_exchanges)
      return if entity_transaction.blank?

      existing_by_number = existing_exchanges.index_by(&:number)
      metadata = exchange_sync_metadata(desired_rows)

      sync_exchange_rows!(
        transaction:,
        desired_rows:,
        existing_by_number:,
        entity_transaction:,
        bound_type:,
        metadata:
      )
      delete_extra_exchange_rows!(existing_by_number)
      update_exchange_owner!(entity_transaction, metadata)
    end
  end

  def exchange_rows_for(transaction)
    transaction.exchanges.monetary.order(:number, :date).to_a
  end

  def exchange_entity_transaction(existing_exchanges)
    existing_exchanges.first&.entity_transaction
  end

  def exchange_bound_type(existing_exchanges)
    existing_exchanges.first&.bound_type || "standalone"
  end

  def exchange_sync_metadata(desired_rows)
    {
      now: Time.current,
      exchanges_count: desired_rows.count,
      total_price: desired_rows.sum { |row| row[:price] }
    }
  end

  def sync_exchange_rows!(**context)
    context[:desired_rows].each do |row|
      exchange = context[:existing_by_number].delete(row[:number])

      if exchange.present?
        update_exchange_row!(exchange, row, context[:metadata])
      else
        create_exchange_row!(context[:transaction], row, context[:entity_transaction], context[:bound_type], context[:metadata])
      end
    end
  end

  def update_exchange_row!(exchange, row, metadata)
    exchange.update_columns(
      date: row[:date],
      month: row[:month],
      year: row[:year],
      price: row[:price],
      starting_price: row[:price],
      exchanges_count: metadata[:exchanges_count],
      updated_at: metadata[:now]
    )
  end

  def create_exchange_row!(transaction, row, entity_transaction, bound_type, metadata)
    Exchange.insert({
                      entity_transaction_id: entity_transaction.id,
                      cash_transaction_id: transaction.id,
                      bound_type:,
                      exchange_type: Exchange.exchange_types.fetch(:monetary),
                      number: row[:number],
                      date: row[:date],
                      month: row[:month],
                      year: row[:year],
                      price: row[:price],
                      starting_price: row[:price],
                      exchanges_count: metadata[:exchanges_count],
                      created_at: metadata[:now],
                      updated_at: metadata[:now]
                    })
  end

  def delete_extra_exchange_rows!(existing_by_number)
    Exchange.where(id: existing_by_number.values.map(&:id)).delete_all if existing_by_number.present?
  end

  def update_exchange_owner!(entity_transaction, metadata)
    entity_transaction.update_columns(
      price: metadata[:total_price],
      price_to_be_returned: metadata[:total_price],
      exchanges_count: metadata[:exchanges_count],
      updated_at: metadata[:now]
    )
    entity_transaction.exchanges.update_all(exchanges_count: metadata[:exchanges_count], updated_at: metadata[:now])
  end

  def serialize_update(transaction, desired_rows)
    {
      exchange_return_transaction_id: transaction.id,
      exchange_bound_types: transaction.exchanges.monetary.distinct.pluck(:bound_type),
      counterpart_transaction_id: transaction.counterpart_shared_return_transaction&.id,
      desired_exchange_rows: desired_rows.map do |row|
        row.merge(date: row[:date]&.to_date&.iso8601)
      end
    }
  end

  def needs_projection_sync?(transaction)
    current_exchange_rows(transaction) != desired_exchange_rows(transaction)
  end

  def desired_exchange_rows(transaction)
    transaction.cash_installments.order(:number, :date).map do |installment|
      {
        number: installment.number,
        date: installment.date,
        month: installment.month,
        year: installment.year,
        price: installment.price
      }
    end
  end

  def current_exchange_rows(transaction)
    transaction.exchanges.monetary.order(:number, :date).map do |exchange|
      {
        number: exchange.number,
        date: exchange.date,
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
