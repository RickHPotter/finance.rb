# frozen_string_literal: true

class Logic::ExchangeReturnAudit # rubocop:disable Metrics/ClassLength
  attr_reader :audit_context, :current_user, :status_filter

  def initialize(current_user:, current_context: nil, status_filter: "pending")
    @audit_context = current_context || current_user.ensure_main_context!
    @current_user = current_user
    @status_filter = %w[paid pending].include?(status_filter) ? status_filter : "pending"
  end

  def call
    rows_by_transaction_id = exchange_returns.each_with_object({}) do |cash_transaction, rows|
      row = build_row(cash_transaction)
      rows[cash_transaction.id] = row if row.present?
    end

    message_replay_mismatch_rows.each do |message_row|
      cash_transaction = message_row.delete(:cash_transaction)
      row = rows_by_transaction_id[cash_transaction.id] || build_row(cash_transaction, include_clean: true)
      row[:message_replay_rows] << message_row
      row[:issues] = (row[:issues] + [ "message_replay_payload_mismatch" ]).uniq
      rows_by_transaction_id[cash_transaction.id] = row
    end

    rows_by_transaction_id.values.sort_by { |row| [ row[:date] || Time.zone.at(0), row[:id] ] }.reverse
  end

  private

  def exchange_returns
    scope = audit_context.cash_transactions
                         .exchange_return
                         .includes(
                           :cash_installments,
                           exchanges: { entity_transaction: [ :entity, { transactable: [ :card_installments, { entity_transactions: :entity } ] } ] }
                         )
                         .order(date: :desc, id: :desc)

    status_filter == "paid" ? scope.where(paid: true) : scope.where(paid: false)
  end

  def build_row(cash_transaction, include_clean: false)
    linked_source_rows = linked_source_rows_for(cash_transaction)
    source_allocation_rows = source_allocation_rows_for(linked_source_rows)
    card_bound_projection_rows = card_bound_projection_rows_for(cash_transaction)
    row = base_row_for(cash_transaction, linked_source_rows, source_allocation_rows, card_bound_projection_rows)
    row[:context] = {
      id: audit_context.id,
      name: audit_context.name,
      scenario_key: audit_context.scenario_key
    }
    row[:paid] = cash_transaction.paid
    row[:status_filter] = status_filter

    row[:issues] = issues_for(row)
    return if row[:issues].empty? && !include_clean

    row
  end

  def linked_source_rows_for(cash_transaction)
    return [] unless cash_transaction.exchange_return?

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

  def base_row_for(cash_transaction, linked_source_rows, source_allocation_rows, card_bound_projection_rows)
    {
      id: cash_transaction.id,
      description: cash_transaction.description,
      date: cash_transaction.date,
      month_year: cash_transaction.month_year,
      price: cash_transaction.price,
      installments_sum: cash_transaction.cash_installments.sum(:price),
      exchange_rows_sum: cash_transaction.exchanges.sum(:price),
      exchange_return: cash_transaction.exchange_return?,
      message_replay_rows: [],
      card_bound_projection_rows:,
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
    issues << "exchange_rows_total_mismatch" if row[:exchange_return] && row[:price] != row[:exchange_rows_sum]
    issues << "stale_linked_source_rows" if row[:linked_source_rows].present?
    issues << "source_allocation_mismatch" if row[:source_allocation_rows].present?
    issues << "card_bound_bill_projection_mismatch" if row[:card_bound_projection_rows].present?
    issues
  end

  def card_bound_projection_rows_for(cash_transaction)
    return [] unless cash_transaction.exchange_return?

    (own_card_bound_projection_rows_for(cash_transaction) + incoming_card_bound_projection_rows_for(cash_transaction))
      .select { |row| row[:issue_code].present? }
      .uniq { |row| [ row[:exchange_id], row[:issue_code] ] }
  end

  def own_card_bound_projection_rows_for(cash_transaction)
    card_bound_exchanges_for(cash_transaction)
      .group_by { |exchange| exchange.entity_transaction&.transactable }
      .flat_map { |source_transaction, exchanges| source_card_bound_projection_rows_for(source_transaction, exchanges) }
  end

  def incoming_card_bound_projection_rows_for(cash_transaction)
    user_card_ids = card_bound_source_user_card_ids_for(cash_transaction)
    return [] if user_card_ids.empty?

    stale_card_bound_exchanges_for(cash_transaction)
      .select { |exchange| card_bound_source_user_card_ids_for_exchange(exchange).intersect?(user_card_ids) }
      .filter_map { |exchange| incoming_card_bound_projection_row_for(exchange, cash_transaction) }
  end

  def card_bound_exchanges_for(cash_transaction)
    cash_transaction.exchanges.select(&:card_bound?).select(&:monetary?)
  end

  def card_bound_source_user_card_ids_for(cash_transaction)
    card_bound_exchanges_for(cash_transaction)
      .filter_map { |exchange| exchange.entity_transaction&.transactable }
      .grep(CardTransaction)
      .filter_map(&:user_card_id)
      .uniq
  end

  def card_bound_source_user_card_ids_for_exchange(exchange)
    source_transaction = exchange.entity_transaction&.transactable
    return [] unless source_transaction.is_a?(CardTransaction)

    [ source_transaction.user_card_id ].compact
  end

  def stale_card_bound_exchanges_for(cash_transaction)
    Exchange
      .monetary
      .card_bound
      .joins(:cash_transaction)
      .where(cash_transactions: { context_id: audit_context.id })
      .where.not(cash_transaction_id: cash_transaction.id)
      .includes(:cash_transaction, entity_transaction: :entity)
  end

  def source_card_bound_projection_rows_for(source_transaction, exchanges)
    return [] unless source_transaction.is_a?(CardTransaction)
    return [] unless source_transaction.card_installments.size == exchanges.size

    exchanges.filter_map { |exchange| card_bound_projection_row_for(exchange, source_transaction) }
  end

  def card_bound_projection_row_for(exchange, source_transaction)
    source_installment = source_transaction.card_installments.find { |installment| installment.number == exchange.number }
    expected_month = source_installment&.month
    expected_year = source_installment&.year
    expected_price = source_installment&.price.to_i.abs
    actual_price = exchange.price.to_i.abs

    issue_code = card_bound_projection_issue_for(exchange, source_installment, expected_price, actual_price)
    return if issue_code.blank?

    {
      exchange_id: exchange.id,
      entity_transaction_id: exchange.entity_transaction_id,
      entity_name: exchange.entity_transaction.entity&.entity_name,
      source_type: source_transaction.class.name,
      source_id: source_transaction.id,
      source_description: source_transaction.description,
      number: exchange.number,
      exchange_month: exchange.month,
      exchange_year: exchange.year,
      exchange_price: exchange.price,
      expected_month:,
      expected_year:,
      expected_price:,
      issue_code:
    }
  end

  def card_bound_projection_issue_for(exchange, source_installment, expected_price, actual_price)
    return "missing_card_installment" if source_installment.blank?
    return "card_bound_bill_bucket_mismatch" if exchange.month != source_installment.month || exchange.year != source_installment.year

    "card_bound_bill_price_mismatch" if actual_price != expected_price
  end

  def incoming_card_bound_projection_row_for(exchange, cash_transaction)
    source_transaction = exchange.entity_transaction&.transactable
    return unless source_transaction.is_a?(CardTransaction)

    source_installment = source_transaction.card_installments.find { |installment| installment.number == exchange.number }
    return if source_installment.blank?
    return unless same_bucket?(source_installment, cash_transaction)
    return if same_bucket?(exchange, source_installment)

    incoming_card_bound_projection_row_attributes(exchange, source_transaction, source_installment)
  end

  def same_bucket?(left, right)
    left.month == right.month && left.year == right.year
  end

  def incoming_card_bound_projection_row_attributes(exchange, source_transaction, source_installment)
    {
      exchange_id: exchange.id,
      entity_transaction_id: exchange.entity_transaction_id,
      entity_name: exchange.entity_transaction.entity&.entity_name,
      source_type: source_transaction.class.name,
      source_id: source_transaction.id,
      source_description: source_transaction.description,
      number: exchange.number,
      exchange_month: exchange.month,
      exchange_year: exchange.year,
      exchange_price: exchange.price,
      expected_month: source_installment.month,
      expected_year: source_installment.year,
      expected_price: source_installment.price.to_i.abs,
      issue_code: "card_bound_bill_merge_target"
    }
  end

  def message_replay_mismatch_rows
    assistant_notification_messages.filter_map do |message|
      local_reference = message.local_reference_for(context: audit_context)
      next if local_reference.blank?
      next unless audited_status?(local_reference)
      next unless local_reference.exchange_return? || local_reference.borrow_return?

      diffs = replay_diffs_for(message, local_reference)
      next if diffs.empty?

      {
        cash_transaction: local_reference,
        message_id: message.id,
        conversation_id: message.conversation_id,
        preview: message.preview_body,
        intent: message.replay_payload.to_h["intent"],
        diffs:
      }
    end
  end

  def assistant_notification_messages
    Message
      .joins(conversation: :conversation_participants)
      .where(conversations: { kind: Conversation.kinds.fetch(:assistant) })
      .where(conversation_participants: { user_id: current_user.id })
      .where(body: [ "notification:create", "notification:update" ], superseded_by_id: nil)
      .where.not(headers: [ nil, "" ])
      .includes(:conversation, :reference_transactable)
      .order(created_at: :desc, id: :desc)
  end

  def audited_status?(cash_transaction)
    status_filter == "paid" ? cash_transaction.paid? : !cash_transaction.paid?
  end

  def replay_diffs_for(message, cash_transaction)
    payload = message.replay_payload.to_h
    diffs = comparable_payload_attributes.each_with_object({}) do |attribute, result|
      next unless payload.key?(attribute)

      local_value = normalized_replay_value(attribute, cash_transaction.public_send(attribute))
      payload_value = normalized_replay_value(attribute, payload[attribute])
      next if local_value == payload_value

      result[attribute] = { local: local_value, payload: payload_value }
    end

    installment_diffs = replay_installment_diffs_for(payload, cash_transaction)
    diffs["cash_installments_attributes"] = installment_diffs if installment_diffs.present?
    diffs
  end

  def comparable_payload_attributes
    %w[description date month year price paid user_bank_account_id]
  end

  def replay_installment_diffs_for(payload, cash_transaction)
    payload_installments = Array(payload["cash_installments_attributes"])
    return [] if payload_installments.empty?

    local_installments = cash_transaction.cash_installments.index_by(&:number)
    payload_installments.filter_map do |payload_installment|
      number = payload_installment["number"].to_i
      local_installment = local_installments[number]
      next if local_installment.blank?

      diffs = %w[date month year price paid].each_with_object({}) do |attribute, result|
        next unless payload_installment.key?(attribute)

        local_value = normalized_replay_value(attribute, local_installment.public_send(attribute))
        payload_value = normalized_replay_value(attribute, payload_installment[attribute])
        next if local_value == payload_value

        result[attribute] = { local: local_value, payload: payload_value }
      end
      next if diffs.empty?

      { number:, diffs: }
    end
  end

  def normalized_replay_value(attribute, value)
    return value.to_i if attribute.in?(%w[month year price user_bank_account_id])
    return ActiveModel::Type::Boolean.new.cast(value) if attribute == "paid"
    return normalize_replay_time(value) if attribute == "date"

    value
  end

  def normalize_replay_time(value)
    return if value.blank?
    return value.to_time.change(usec: 0) if value.respond_to?(:to_time)

    Time.zone.parse(value.to_s)&.change(usec: 0)
  rescue ArgumentError
    value
  end
end
