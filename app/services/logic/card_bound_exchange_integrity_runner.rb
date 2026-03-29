# frozen_string_literal: true

class Logic::CardBoundExchangeIntegrityRunner
  attr_reader :ids, :year, :month, :dry_run

  def initialize(ids: nil, year: nil, month: nil, dry_run: true)
    @ids = Array(ids).compact_blank.map(&:to_i)
    @year = year.presence&.to_i
    @month = month.presence&.to_i
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      processed_count: families.size,
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

  def families
    @families ||= grouped_exchanges.values
  end

  def grouped_exchanges
    @grouped_exchanges ||= target_exchanges.group_by do |exchange|
      transactable = exchange.entity_transaction.transactable

      [
        transactable.user_id,
        transactable.context_id,
        transactable.user_card_id,
        exchange.send(:projection_description),
        exchange.year,
        exchange.month
      ]
    end
  end

  def target_exchanges
    @target_exchanges ||= begin
      scope = Exchange.includes(entity_transaction: :transactable)
                      .monetary
                      .card_bound
                      .where(cash_transaction_id: nil)
                      .order(:entity_transaction_id, :year, :month, :number, :date, :id)
      scope = scope.where(id: ids) if ids.present?
      scope = scope.where(year:) if year.present?
      scope = scope.where(month:) if month.present?

      scope.to_a
    end
  end

  def run
    families.each_with_object({ updates: [], skipped: [] }) do |family, result|
      process_family(family, result)
    end
  end

  def process_family(family, result)
    issues = Logic::CardBoundExchangeIntegrityAudit.new(ids: family.map(&:id)).call[:candidates].first&.fetch(:issues, []) || []
    first_exchange = family.first
    existing_projection = first_exchange.send(:existing_card_bound_projection_cash_transaction)

    return result[:skipped] << serialize_skip(family, "existing_projection_paid_history", issues) if existing_projection&.paid_history?
    return result[:updates] << serialize_update(family, existing_projection, issues) if dry_run

    apply_family_with_reporting(family, existing_projection, issues, result)
  end

  def apply_family_with_reporting(family, existing_projection, issues, result)
    apply_family!(family, existing_projection)
    rebuilt_family = Exchange.where(id: family.map(&:id)).includes(entity_transaction: :transactable).order(:date, :number, :id).to_a
    result[:updates] << serialize_update(rebuilt_family, rebuilt_family.first.send(:existing_card_bound_projection_cash_transaction), issues)
  rescue StandardError => e
    result[:skipped] << serialize_skip(family, "apply_failed", issues, e)
  end

  def apply_family!(family, existing_projection)
    first_exchange = family.first
    cash_transaction = existing_projection || CashTransaction.create!(first_exchange.send(:projection_cash_transaction_params))
    exchange_ids = family.map(&:id)

    CashTransaction.transaction do
      cash_transaction.with_lock do
        Exchange.where(id: exchange_ids).update_all(cash_transaction_id: cash_transaction.id, updated_at: Time.current)
        exchanges = Exchange.where(id: exchange_ids).order(:date, :number, :id).to_a
        first_exchange.send(:sync_projection_cash_transaction!, cash_transaction:, exchanges:)
        cash_transaction.reload.sync_exchange_entity_transaction_statuses!
      end
    end
  end

  def serialize_update(family, cash_transaction, issues)
    first_exchange = family.first
    transactable = first_exchange.entity_transaction.transactable

    {
      issues:,
      entity_transaction_ids: family.map(&:entity_transaction_id).uniq,
      user_id: transactable.user_id,
      context_id: transactable.context_id,
      user_card_id: transactable.user_card_id,
      year: first_exchange.year,
      month: first_exchange.month,
      exchange_ids: family.map(&:id),
      cash_transaction_id: cash_transaction&.id,
      exchanges_sum_price: family.sum(&:price)
    }
  end

  def serialize_skip(family, reason, issues, error = nil)
    first_exchange = family.first
    transactable = first_exchange.entity_transaction.transactable

    {
      reason:,
      issues:,
      entity_transaction_ids: family.map(&:entity_transaction_id).uniq,
      user_id: transactable.user_id,
      context_id: transactable.context_id,
      user_card_id: transactable.user_card_id,
      year: first_exchange.year,
      month: first_exchange.month,
      exchange_ids: family.map(&:id),
      error_class: error&.class&.name,
      error_message: error&.message
    }.compact
  end
end
