# frozen_string_literal: true

class Logic::StandaloneExchangeIntegrityRunner
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
    @updates ||= run_result[:updates]
  end

  def skipped
    @skipped ||= run_result[:skipped]
  end

  def run_result
    @run_result ||= run
  end

  def run
    target_transactions.each_with_object({ updates: [], skipped: [] }) do |transaction, result|
      issues = audit_issues_for(transaction)
      next if issues.empty?

      entity_transactions = payer_entity_transactions_for(transaction)
      if entity_transactions.size != 1
        result[:skipped] << { exchange_return_transaction_id: transaction.id, reason: "multiple_payer_entity_transactions", issues: }
        next
      end

      next result[:updates] << serialize_update(transaction, entity_transactions.first, issues) if dry_run

      begin
        apply_corrections!(transaction, entity_transactions.first)
        result[:updates] << serialize_update(transaction.reload, entity_transactions.first.reload, issues)
      rescue StandardError => e
        result[:skipped] << {
          exchange_return_transaction_id: transaction.id,
          reason: "apply_failed",
          issues:,
          error_class: e.class.name,
          error_message: e.message
        }
      end
    end
  end

  def target_transactions
    @target_transactions ||= begin
      scope = CashTransaction.includes(:cash_installments, exchanges: :entity_transaction).exchange_return.order(:id)
      scope = scope.where(id: ids) if ids.present?

      scope.select { |transaction| standalone_exchange_return_candidate?(transaction) }
    end
  end

  def apply_corrections!(transaction, entity_transaction)
    exchanges = standalone_monetary_exchanges_for(transaction)

    CashTransaction.transaction do
      transaction.with_lock do
        exchanges_sum_price = exchanges.sum(&:price)
        exchanges_count = exchanges.size
        now = Time.current
        price_should_follow_price_to_be_returned = entity_transaction.price == entity_transaction.price_to_be_returned

        corrected_entity_transaction_attributes = {
          price_to_be_returned: exchanges_sum_price,
          exchanges_count: exchanges_count,
          is_payer: !exchanges_sum_price.zero?,
          updated_at: now
        }
        corrected_entity_transaction_attributes[:price] = exchanges_sum_price if price_should_follow_price_to_be_returned

        entity_transaction.update_columns(corrected_entity_transaction_attributes)

        exchanges.each do |exchange|
          next if exchange.exchanges_count == exchanges_count

          exchange.update_columns(exchanges_count:, updated_at: now)
        end

        exchanges.first.send(:sync_projection_cash_transaction!, cash_transaction: transaction, exchanges:)
        transaction.reload.sync_exchange_entity_transaction_statuses!
      end
    end
  end

  def serialize_update(transaction, entity_transaction, issues)
    exchanges = standalone_monetary_exchanges_for(transaction)

    {
      exchange_return_transaction_id: transaction.id,
      entity_transaction_id: entity_transaction.id,
      issues:,
      corrected: {
        cash_installments_count: transaction.cash_installments.size,
        cash_installments_count_column: transaction.cash_installments_count,
        exchanges_count: exchanges.size,
        exchanges_sum_price: exchanges.sum(&:price),
        entity_transaction_price: entity_transaction.price,
        entity_transaction_price_to_be_returned: entity_transaction.price_to_be_returned,
        entity_transaction_exchanges_count: entity_transaction.exchanges_count
      }
    }
  end

  def audit_issues_for(transaction)
    Logic::StandaloneExchangeIntegrityAudit.new(ids: [ transaction.id ]).call[:candidates].first&.fetch(:issues, []) || []
  end

  def standalone_exchange_return_candidate?(transaction)
    transaction.exchanges.monetary.distinct.pluck(:bound_type) == [ "standalone" ]
  end

  def standalone_monetary_exchanges_for(transaction)
    transaction.exchanges.monetary.standalone.order(:date, :number, :id).to_a
  end

  def payer_entity_transactions_for(transaction)
    standalone_monetary_exchanges_for(transaction).map(&:entity_transaction).uniq(&:id)
  end
end
