# frozen_string_literal: true

class Logic::CardExchangeProjectionRepair # rubocop:disable Metrics/ClassLength
  attr_reader :current_context, :current_user

  def initialize(current_user:, current_context:, cash_transaction:)
    @current_user = current_user
    @current_context = current_context
    @cash_transaction = cash_transaction
  end

  def call
    ActiveRecord::Base.transaction do
      fix_stale_card_bound_projection_buckets! if stale_card_bound_projection_bucket_fixable?
      move_out_of_bucket_projection_exchanges!
      sync_current_projection_exchanges!
      @duplicate_card_bound_projection_transactions = nil
      @cash_transaction = merge_duplicate_card_bound_projection_transactions!
      sync_current_projection_exchanges!
    end

    @cash_transaction
  end

  def fixable?
    @cash_transaction.exchange_return? &&
      projection_exchanges.present? &&
      (@cash_transaction.price != projection_exchanges.sum(&:price) ||
        stale_card_bound_projection_bucket_fixable? ||
        out_of_bucket_card_bound_projection_exchanges.present? ||
        incoming_wrong_owner_card_bound_projection_exchanges.present? ||
        duplicate_card_bound_projection_transactions.present?)
  end

  def preview_changes
    [
      *stale_bucket_changes,
      *rehome_changes,
      *duplicate_merge_changes,
      projection_total_change
    ].compact
  end

  def graph_snapshot
    {
      cash_transaction: snapshot_transaction(@cash_transaction),
      projection_exchanges: projection_exchanges.sort_by(&:id).map { |exchange| snapshot_exchange(exchange) },
      incoming_stale_exchanges: incoming_stale_card_bound_projection_exchanges.sort_by(&:id).map { |exchange| snapshot_exchange(exchange) },
      incoming_wrong_owner_exchanges: incoming_wrong_owner_card_bound_projection_exchanges.sort_by(&:id).map { |exchange| snapshot_exchange(exchange) },
      duplicate_transactions: duplicate_card_bound_projection_transactions.sort_by(&:id).map { |transaction| snapshot_transaction(transaction) }
    }
  end

  def paid_history
    transactions = current_context.cash_transactions
                                  .includes(:cash_installments)
                                  .where(id: affected_cash_transaction_ids)
                                  .order(:id)
    paid_transactions = transactions.select { |transaction| transaction.paid? || transaction.cash_installments.any?(&:paid?) }

    {
      affected: paid_transactions.any?,
      affected_transaction_ids: transactions.map(&:id),
      paid_transaction_ids: paid_transactions.map(&:id)
    }
  end

  def affected_references
    exchanges = affected_exchanges
    card_transactions = exchanges.filter_map { |exchange| exchange.entity_transaction&.transactable }.grep(CardTransaction).uniq(&:id)
    cash_transactions = current_context.cash_transactions.includes(:cash_installments).where(id: affected_cash_transaction_ids).order(:id)

    [
      { type: "CashTransaction", ids: cash_transactions.map(&:id), role: "repair_graph_cash_transactions" },
      { type: "CashInstallment", ids: cash_transactions.flat_map do |transaction|
        transaction.cash_installments.map(&:id)
      end.sort, role: "repair_graph_cash_installments" },
      { type: "Exchange", ids: exchanges.map(&:id).sort, role: "repair_graph_exchanges" },
      { type: "CardTransaction", ids: card_transactions.map(&:id).sort, role: "repair_graph_card_transactions" },
      { type: "CardInstallment", ids: card_transactions.flat_map do |transaction|
        transaction.card_installments.map(&:id)
      end.sort, role: "repair_graph_card_installments" }
    ]
  end

  private

  def affected_cash_transaction_ids
    [
      @cash_transaction.id,
      *projection_exchanges.map(&:cash_transaction_id),
      *incoming_stale_card_bound_projection_exchanges.map(&:cash_transaction_id),
      *incoming_wrong_owner_card_bound_projection_exchanges.map(&:cash_transaction_id),
      *duplicate_card_bound_projection_transactions.map(&:id)
    ].compact.uniq.sort
  end

  def affected_exchanges
    [
      *projection_exchanges,
      *incoming_stale_card_bound_projection_exchanges,
      *incoming_wrong_owner_card_bound_projection_exchanges,
      *duplicate_card_bound_projection_transactions.flat_map { |transaction| transaction.exchanges.to_a }
    ].uniq(&:id).sort_by(&:id)
  end

  def move_out_of_bucket_projection_exchanges!
    @out_of_bucket_card_bound_projection_exchanges = nil
    @incoming_wrong_owner_card_bound_projection_exchanges = nil
    rehomed_projection_transactions = rehome_out_of_bucket_card_bound_projection_exchanges!
    @projection_exchanges = nil
    @cash_transaction.reload
    return unless projection_exchanges.empty? && rehomed_projection_transactions.present?

    @cash_transaction.destroy!
    @cash_transaction = rehomed_projection_transactions.first.reload
    @projection_exchanges = nil
  end

  def sync_current_projection_exchanges!
    @projection_exchanges = nil
    projection_exchanges.first&.send(:sync_projection_cash_transaction!, cash_transaction: @cash_transaction, exchanges: projection_exchanges)
    @cash_transaction.reload
  end

  def projection_exchanges
    @projection_exchanges ||= @cash_transaction.exchanges.includes(entity_transaction: :entity).card_bound.monetary
  end

  def stale_card_bound_projection_bucket_fixable?
    stale_own_card_bound_projection_exchanges.present? || incoming_stale_card_bound_projection_exchanges.present?
  end

  def merge_duplicate_card_bound_projection_transactions!
    target = preferred_duplicate_card_bound_projection_transaction
    return @cash_transaction if target.blank?

    duplicate_card_bound_projection_transactions.where.not(id: target.id).find_each do |duplicate|
      Audit::BulkMutation.update_all!(duplicate.cash_installments.where(paid: true), cash_transaction_id: target.id, updated_at: Time.current)
      Audit::BulkMutation.update_all!(duplicate.exchanges, cash_transaction_id: target.id, updated_at: Time.current)
      duplicate.reload
      duplicate.destroy!
    end

    normalize_merged_paid_installment_numbers!(target)
    projection_price = target.exchanges.card_bound.monetary.sum(:price)
    Audit::BulkMutation.update_columns!(target, starting_price: projection_price, price: projection_price, updated_at: Time.current)
    target.reload
  end

  def normalize_merged_paid_installment_numbers!(target)
    target.cash_installments.where(paid: true).order(:date, :number, :id).each_with_index do |installment, index|
      number = index + 1
      next if installment.number == number

      Audit::BulkMutation.update_columns!(installment, number:, updated_at: Time.current)
    end
  end

  def preferred_duplicate_card_bound_projection_transaction
    duplicate_card_bound_projection_transactions.max_by do |transaction|
      [
        transaction.user_card_id.present? ? 1 : 0,
        transaction.cash_installments.any? { |installment| !installment.paid? } ? 1 : 0,
        transaction.exchanges.size,
        transaction.cash_installments.any?(&:paid?) ? 1 : 0,
        transaction.updated_at.to_i,
        transaction.id
      ]
    end
  end

  def duplicate_card_bound_projection_transactions
    @duplicate_card_bound_projection_transactions ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        current_context.cash_transactions.where(id: @cash_transaction.id)
      else
        duplicate_ids = current_context.cash_transactions
                                       .exchange_return
                                       .where(
                                         user_id: current_user.id,
                                         user_card_id: user_card_ids,
                                         cash_transaction_type: @cash_transaction.cash_transaction_type,
                                         description: @cash_transaction.description,
                                         month: @cash_transaction.month,
                                         year: @cash_transaction.year
                                       )
                                       .pluck(:id)
        current_context.cash_transactions.where(id: [ @cash_transaction.id, *duplicate_ids ].uniq)
                       .includes(:cash_installments, exchanges: { entity_transaction: :entity })
      end
    end
  end

  def fix_stale_card_bound_projection_buckets!
    (stale_own_card_bound_projection_exchanges + incoming_stale_card_bound_projection_exchanges).uniq.each do |exchange|
      source_installment = card_bound_projection_source_installment(exchange)
      next if source_installment.blank?

      Audit::BulkMutation.update_columns!(
        exchange,
        month: source_installment.month,
        year: source_installment.year,
        date: card_bound_projection_reference_date(exchange, source_installment),
        updated_at: Time.current
      )
    end
  end

  def rehome_out_of_bucket_card_bound_projection_exchanges!
    rehomed_projection_transactions = []
    (out_of_bucket_card_bound_projection_exchanges + incoming_wrong_owner_card_bound_projection_exchanges).uniq.each do |exchange|
      Audit::BulkMutation.update_columns!(exchange, cash_transaction_id: nil, updated_at: Time.current)
      exchange.reload
      exchange.send(:create_cash_transaction)
      exchange.save!
      rehomed_projection_transactions << exchange.reload.cash_transaction if exchange.cash_transaction.present?
    end
    rehomed_projection_transactions.uniq
  end

  def out_of_bucket_card_bound_projection_exchanges
    @out_of_bucket_card_bound_projection_exchanges ||= projection_exchanges.reject do |exchange|
      exchange.month == @cash_transaction.month && exchange.year == @cash_transaction.year
    end
  end

  def incoming_wrong_owner_card_bound_projection_exchanges
    @incoming_wrong_owner_card_bound_projection_exchanges ||= begin
      group_keys = projection_exchange_group_keys
      if group_keys.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: duplicate_card_bound_projection_transactions.map(&:id))
                .includes(entity_transaction: :entity)
                .select do |exchange|
                  incoming_wrong_owner_card_bound_projection_exchange?(exchange, group_keys)
                end
      end
    end
  end

  def incoming_wrong_owner_card_bound_projection_exchange?(exchange, group_keys)
    source_transaction = exchange.entity_transaction&.transactable
    return false unless source_transaction.is_a?(CardTransaction)
    return false unless group_keys.include?([ source_transaction.user_card_id, exchange.entity_transaction.entity_id ])
    return false unless exchange.month == @cash_transaction.month && exchange.year == @cash_transaction.year

    source_installment = card_bound_projection_source_installment(exchange)
    source_installment.present? && source_installment.month == @cash_transaction.month && source_installment.year == @cash_transaction.year
  end

  def projection_exchange_group_keys
    projection_exchanges.filter_map do |exchange|
      source_transaction = exchange.entity_transaction&.transactable
      [ source_transaction.user_card_id, exchange.entity_transaction.entity_id ] if source_transaction.is_a?(CardTransaction)
    end.uniq
  end

  def stale_own_card_bound_projection_exchanges
    @stale_own_card_bound_projection_exchanges ||= projection_exchanges.select do |exchange|
      stale_card_bound_projection_exchange?(exchange)
    end
  end

  def incoming_stale_card_bound_projection_exchanges
    @incoming_stale_card_bound_projection_exchanges ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: @cash_transaction.id)
                .includes(entity_transaction: :entity)
                .select do |exchange|
                  incoming_stale_card_bound_projection_exchange?(exchange, user_card_ids)
                end
      end
    end
  end

  def incoming_stale_card_bound_projection_exchange?(exchange, user_card_ids)
    source_transaction = exchange.entity_transaction&.transactable
    return false unless source_transaction.is_a?(CardTransaction)
    return false unless user_card_ids.include?(source_transaction.user_card_id)

    source_installment = card_bound_projection_source_installment(exchange)
    return false if source_installment.blank?
    return false unless source_installment.month == @cash_transaction.month && source_installment.year == @cash_transaction.year

    stale_card_bound_projection_exchange?(exchange)
  end

  def stale_card_bound_projection_exchange?(exchange)
    source_installment = card_bound_projection_source_installment(exchange)
    return false if source_installment.blank?

    exchange.month != source_installment.month || exchange.year != source_installment.year
  end

  def projection_exchange_user_card_ids
    projection_exchanges.filter_map do |exchange|
      source_transaction = exchange.entity_transaction&.transactable
      source_transaction.user_card_id if source_transaction.is_a?(CardTransaction)
    end.uniq
  end

  def card_bound_projection_source_installment(exchange)
    source_transaction = exchange.entity_transaction&.transactable
    return unless source_transaction.is_a?(CardTransaction)

    source_transaction.card_installments.find_by(number: exchange.number)
  end

  def card_bound_projection_reference_date(exchange, source_installment)
    source_transaction = exchange.entity_transaction&.transactable
    reference = source_transaction.user_card.references.find_by(
      context: source_transaction.context,
      month: source_installment.month,
      year: source_installment.year
    )

    return reference.reference_date.end_of_day if reference.present?

    due_day = [ source_transaction.user_card.due_date_day, Time.days_in_month(source_installment.month, source_installment.year) ].min
    Time.zone.local(source_installment.year, source_installment.month, due_day).end_of_day
  end

  def stale_bucket_changes
    (stale_own_card_bound_projection_exchanges + incoming_stale_card_bound_projection_exchanges).uniq.sort_by(&:id).filter_map do |exchange|
      source_installment = card_bound_projection_source_installment(exchange)
      next if source_installment.blank?

      {
        record_type: "Exchange",
        record_id: exchange.id,
        attribute: "projection_bucket",
        before: { month: exchange.month, year: exchange.year, date: exchange.date },
        after: {
          month: source_installment.month,
          year: source_installment.year,
          date: card_bound_projection_reference_date(exchange, source_installment)
        },
        metadata: { cash_transaction_id: exchange.cash_transaction_id, number: exchange.number }
      }
    end
  end

  def rehome_changes
    (out_of_bucket_card_bound_projection_exchanges + incoming_wrong_owner_card_bound_projection_exchanges).uniq.sort_by(&:id).map do |exchange|
      {
        record_type: "Exchange",
        record_id: exchange.id,
        attribute: "cash_transaction_id",
        before: exchange.cash_transaction_id,
        after: "projection_bucket_target",
        metadata: { month: exchange.month, year: exchange.year, number: exchange.number }
      }
    end
  end

  def duplicate_merge_changes
    target = preferred_duplicate_card_bound_projection_transaction
    return [] if target.blank?

    duplicate_card_bound_projection_transactions.reject { |transaction| transaction.id == target.id }.sort_by(&:id).flat_map do |duplicate|
      exchange_changes = duplicate.exchanges.sort_by(&:id).map do |exchange|
        {
          record_type: "Exchange",
          record_id: exchange.id,
          attribute: "cash_transaction_id",
          before: duplicate.id,
          after: target.id,
          metadata: { merge_target_id: target.id }
        }
      end
      [
        *exchange_changes,
        {
          record_type: "CashTransaction",
          record_id: duplicate.id,
          attribute: "record_state",
          before: "persisted",
          after: "destroyed",
          metadata: { merge_target_id: target.id }
        }
      ]
    end
  end

  def projection_total_change
    projected_total = projection_exchanges.sum(&:price)
    return if @cash_transaction.price == projected_total

    {
      record_type: "CashTransaction",
      record_id: @cash_transaction.id,
      attribute: "price",
      before: @cash_transaction.price,
      after: projected_total,
      metadata: { role: "projection_total" }
    }
  end

  def snapshot_transaction(transaction)
    {
      id: transaction.id,
      price: transaction.price,
      month: transaction.month,
      year: transaction.year,
      updated_at: transaction.updated_at,
      installment_rows: transaction.cash_installments.sort_by(&:id).map do |installment|
        [ installment.id, installment.number, installment.price, installment.month, installment.year, installment.paid, installment.updated_at ]
      end,
      exchange_ids: transaction.exchanges.map(&:id).sort
    }
  end

  def snapshot_exchange(exchange)
    {
      id: exchange.id,
      cash_transaction_id: exchange.cash_transaction_id,
      entity_transaction_id: exchange.entity_transaction_id,
      number: exchange.number,
      price: exchange.price,
      month: exchange.month,
      year: exchange.year,
      date: exchange.date,
      updated_at: exchange.updated_at
    }
  end
end
