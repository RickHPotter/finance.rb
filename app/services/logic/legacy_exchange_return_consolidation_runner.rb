# frozen_string_literal: true

class Logic::LegacyExchangeReturnConsolidationRunner
  attr_reader :ids, :dry_run

  def initialize(ids: nil, dry_run: true)
    @ids = Array(ids).compact_blank.map(&:to_i)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      processed_count: candidate_groups.size,
      updated_count: updates.size,
      skipped_count: skipped.size,
      updates:,
      skipped:
    }
  end

  private

  def updates
    @updates ||= run_result[:updates]
  end

  def skipped
    @skipped ||= run_result[:skipped]
  end

  def run_result
    @run_result ||= run
  end

  def run
    candidate_groups.each_with_object({ updates: [], skipped: [] }) do |group, result|
      survivor = group.min_by(&:id)
      desired_installments = desired_installments_for(group)

      if desired_installments.blank?
        result[:skipped] << { survivor_transaction_id: survivor.id, reason: "desired_installments_blank" }
        next
      end

      next result[:updates] << serialize_update(survivor, group, desired_installments) if dry_run

      consolidate_group!(survivor, group, desired_installments)
      result[:updates] << serialize_update(survivor.reload, group, desired_installments)
    end
  end

  def candidate_groups
    grouped_transactions.values.select { |group| group.size > 1 }
  end

  def grouped_transactions
    target_transactions.each_with_object({}) do |transaction, result|
      key = consolidation_key_for(transaction)
      next if key.blank?

      result[key] ||= []
      result[key] << transaction
    end
  end

  def target_transactions
    scope = CashTransaction.includes(:cash_installments, :exchanges, :categories).exchange_return.order(:id)
    scope = scope.where(id: ids) if ids.present?

    scope.select { |transaction| standalone_exchange_return_candidate?(transaction) }
  end

  def consolidate_group!(survivor, group, desired_installments)
    survivor.with_lock do
      group_ids = group.map(&:id)
      legacy_ids = group_ids - [ survivor.id ]
      grouped_exchanges = Exchange.where(cash_transaction_id: group_ids).monetary.order(:date, :number, :id).to_a

      move_exchanges_to_survivor!(survivor, grouped_exchanges, desired_installments)
      rebuild_survivor_installments!(survivor, desired_installments)
      update_survivor_columns!(survivor, desired_installments)
      delete_legacy_transactions!(legacy_ids)
      survivor.sync_exchange_entity_transaction_statuses!
    end
  end

  def move_exchanges_to_survivor!(survivor, grouped_exchanges, desired_installments)
    grouped_exchanges.zip(desired_installments).each do |exchange, desired_row|
      exchange.update_columns(
        cash_transaction_id: survivor.id,
        number: desired_row[:number],
        date: desired_row[:date],
        month: desired_row[:month],
        year: desired_row[:year],
        price: desired_row[:price],
        starting_price: desired_row[:price],
        exchanges_count: desired_installments.count,
        updated_at: Time.current
      )
    end
  end

  def rebuild_survivor_installments!(survivor, desired_installments)
    survivor.cash_installments.delete_all

    desired_installments.each do |row|
      survivor.cash_installments.create!(
        number: row[:number],
        date: row[:date],
        month: row[:month],
        year: row[:year],
        price: row[:price],
        starting_price: row[:price],
        paid: row[:paid],
        cash_installments_count: desired_installments.count
      )
    end
  end

  def update_survivor_columns!(survivor, desired_installments)
    first_row = desired_installments.min_by { |row| [ row[:number], row[:date] ] }
    total_price = desired_installments.sum { |row| row[:price] }

    survivor.update_columns(
      price: total_price,
      starting_price: total_price,
      date: first_row[:date],
      month: first_row[:month],
      year: first_row[:year],
      cash_installments_count: desired_installments.count,
      paid: desired_installments.all? { |row| row[:paid] },
      updated_at: Time.current
    )
  end

  def delete_legacy_transactions!(legacy_ids)
    legacy_transactions = CashTransaction.where(id: legacy_ids)
    legacy_transactions.find_each do |transaction|
      transaction.cash_installments.delete_all
      transaction.delete
    end
  end

  def serialize_update(survivor, group, desired_installments)
    {
      survivor_transaction_id: survivor.id,
      merged_transaction_ids: group.map(&:id),
      desired_installments_count: desired_installments.count,
      desired_installments: desired_installments.map do |row|
        row.merge(date: row[:date]&.to_date&.iso8601)
      end
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
        date: installment.date,
        month: installment.month,
        year: installment.year,
        price: installment.price,
        paid: installment.paid
      }
    end
  end

  def consolidation_key_for(transaction)
    payer_entity_transaction = transaction.exchanges.monetary.order(:id).first&.entity_transaction
    return if payer_entity_transaction.blank?

    [ transaction.user_id, transaction.context_id, payer_entity_transaction.id ].join(":")
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end
end
