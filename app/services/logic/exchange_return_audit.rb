# frozen_string_literal: true

class Logic::ExchangeReturnAudit # rubocop:disable Metrics/ClassLength
  attr_reader :audit_context, :current_user, :issue_filter, :status_filter, :transaction_ids

  def initialize(current_user:, current_context: nil, issue_filter: nil, status_filter: "pending", transaction_ids: nil)
    @audit_context = current_context || current_user.ensure_main_context!
    @current_user = current_user
    @issue_filter = issue_filter.presence
    @status_filter = %w[paid pending].include?(status_filter) ? status_filter : "pending"
    @transaction_ids = Array(transaction_ids).compact_blank.map(&:to_i).presence
  end

  def call
    rows_by_transaction_id = exchange_return_rows_by_transaction_id

    append_message_replay_rows(rows_by_transaction_id) if issue_enabled?("message_replay_payload_mismatch")

    rows_by_transaction_id.values.sort_by { |row| [ row[:date] || Time.zone.at(0), row[:id] ] }.reverse
  end

  private

  def exchange_return_rows_by_transaction_id
    return {} if issue_filter == "message_replay_payload_mismatch"

    exchange_returns.each_with_object({}) do |cash_transaction, rows|
      row = build_row(cash_transaction)
      rows[cash_transaction.id] = row if row.present?
    end
  end

  def append_message_replay_rows(rows_by_transaction_id)
    message_replay_mismatch_rows.each do |message_row|
      cash_transaction = message_row.delete(:cash_transaction)
      row = rows_by_transaction_id[cash_transaction.id] || build_row(cash_transaction, include_clean: true)
      row[:message_replay_rows] << message_row
      row[:issues] = (row[:issues] + [ "message_replay_payload_mismatch" ]).uniq
      rows_by_transaction_id[cash_transaction.id] = row
    end
  end

  def exchange_returns
    scope = audit_context.cash_transactions
                         .exchange_return
                         .includes(
                           :cash_installments,
                           exchanges: { entity_transaction: [ :entity, { transactable: [ :card_installments, { entity_transactions: :entity } ] } ] }
                         )
                         .order(date: :desc, id: :desc)
    scope = scope.where(id: transaction_ids) if transaction_ids.present?

    status_filter == "paid" ? scope.where(paid: true) : scope.where(paid: false)
  end

  def build_row(cash_transaction, include_clean: false)
    linked_source_rows = linked_source_rows_for(cash_transaction)
    source_allocation_rows = source_allocation_enabled? ? source_allocation_rows_for(linked_source_rows) : []
    card_bound_projection_rows = card_bound_projection_enabled? ? card_bound_projection_rows_for(cash_transaction) : []
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
    return [] unless linked_source_rows_enabled?
    return [] unless cash_transaction.exchange_return?

    cash_transaction.exchanges
                    .map(&:entity_transaction)
                    .compact
                    .select(&:is_payer?)
                    .uniq
                    .map { |entity_transaction| linked_source_row_for(entity_transaction, cash_transaction.id) }
  end

  def linked_source_row_for(entity_transaction, cash_transaction_id)
    totals = linked_source_totals_for(entity_transaction, cash_transaction_id)
    source_transaction = entity_transaction.transactable

    {
      entity_transaction_id: entity_transaction.id,
      entity_name: entity_transaction.entity&.entity_name,
      transactable_type: entity_transaction.transactable_type,
      transactable_id: entity_transaction.transactable_id,
      transactable: source_transaction,
      description: source_transaction&.description,
      aggregate_total: entity_transaction.price_to_be_returned,
      aggregate_exchange_total: totals[:aggregate_exchange_total],
      scoped_exchange_total: totals[:scoped_exchange_total],
      delta: delta_for(entity_transaction, totals[:aggregate_exchange_total]),
      raw_delta: entity_transaction.price_to_be_returned - totals[:aggregate_exchange_total],
      principal_total: entity_transaction.price,
      current_return_price: entity_transaction.price_to_be_returned,
      loan_return_percentage: entity_transaction.loan_return_percentage,
      calculated_loan_return_percentage: entity_transaction.calculated_loan_return_percentage,
      exchanges_count: entity_transaction.exchanges_count,
      transaction_total: source_transaction&.price.to_i.abs,
      friend_notification_intent: friend_notification_intent_for(source_transaction)
    }
  end

  def linked_source_totals_for(entity_transaction, cash_transaction_id)
    {
      scoped_exchange_total: entity_transaction.exchanges.where(cash_transaction_id:).sum(:price),
      aggregate_exchange_total: entity_transaction.exchanges
                                                  .monetary
                                                  .joins(:cash_transaction)
                                                  .where(cash_transactions: { context_id: audit_context.id })
                                                  .sum(:price)
    }
  end

  def source_allocation_rows_for(linked_source_rows)
    linked_source_rows
      .group_by { |entry| [ entry[:transactable_type], entry[:transactable_id] ] }
      .values
      .map { |rows| source_allocation_row_for(rows) }
      .compact
  end

  def source_allocation_row_for(source_entries)
    source_entry = source_entries.first
    transactable = source_entry[:transactable]
    return if transactable.blank?

    entity_totals = source_entity_totals_for(transactable)
    allocation_total = entity_totals[:allocation_total]
    transaction_total = transactable.price.abs
    payer_total = entity_totals[:payer_total]
    has_moi_entity = entity_totals[:has_moi_entity]
    missing_amount = transaction_total - allocation_total
    return if missing_amount.zero?

    intent = friend_notification_intent_for(transactable)
    percentage_source_entry = percentage_source_entry_for(source_entries, missing_amount)
    issue_code = source_allocation_issue_code(intent:, has_moi_entity:, missing_amount:)
    return if source_allocation_issue_resolved?(intent:, issue_code:, transactable:, transaction_total:)

    calculated_values = calculated_allocation_values_for(
      source_entry: percentage_source_entry,
      transaction_total:,
      missing_amount:
    )

    source_allocation_row_attributes({
                                       transactable:,
                                       transaction_total:,
                                       allocation_total:,
                                       payer_total:,
                                       missing_amount:,
                                       has_moi_entity:,
                                       issue_code:,
                                       intent:,
                                       percentage_source_entry:,
                                       calculated_percentage: calculated_values[:percentage],
                                       calculated_price: calculated_values[:price]
                                     })
  end

  def source_allocation_row_attributes(row_context)
    percentage_source_entry = row_context[:percentage_source_entry]

    {
      transactable_type: row_context[:transactable].class.name,
      transactable_id: row_context[:transactable].id,
      description: row_context[:transactable].description,
      transaction_total: row_context[:transaction_total],
      allocation_total: row_context[:allocation_total],
      payer_total: row_context[:payer_total],
      missing_amount: row_context[:missing_amount],
      has_moi_entity: row_context[:has_moi_entity],
      issue_code: row_context[:issue_code],
      friend_notification_intent: row_context[:intent],
      entity_transaction_id: percentage_source_entry[:entity_transaction_id],
      current_price: percentage_source_entry[:principal_total],
      current_return_price: percentage_source_entry[:aggregate_total],
      loan_return_percentage: percentage_source_entry[:loan_return_percentage],
      matched_loan_return_percentage: percentage_source_entry[:calculated_loan_return_percentage],
      calculated_loan_return_percentage: row_context[:calculated_percentage],
      calculated_price: row_context[:calculated_price]
    }
  end

  def source_entity_totals_for(transactable)
    entity_transactions = transactable.entity_transactions.to_a
    {
      allocation_total: entity_transactions.sum(&:price),
      payer_total: entity_transactions.sum(&:price_to_be_returned),
      has_moi_entity: entity_transactions.any? { |entity_transaction| entity_transaction.entity&.built_in? }
    }
  end

  def calculated_allocation_values_for(source_entry:, transaction_total:, missing_amount:)
    {
      percentage: calculated_allocation_percentage(source_entry:, transaction_total:, missing_amount:),
      price: calculated_allocation_price(source_entry:, missing_amount:)
    }
  end

  def calculated_allocation_percentage(source_entry:, transaction_total:, missing_amount:)
    return source_entry[:calculated_loan_return_percentage] if transaction_total.to_i.zero?

    ((calculated_allocation_price(source_entry:, missing_amount:).abs.to_d / transaction_total.to_i.abs) * 100).round(4)
  end

  def calculated_allocation_price(source_entry:, missing_amount:)
    source_entry[:principal_total].to_i + missing_amount.to_i
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

  def delta_for(entity_transaction, aggregate_exchange_total)
    entity_transaction.price_to_be_returned - aggregate_exchange_total
  end

  def friend_notification_intent_for(transactable)
    return unless transactable.respond_to?(:effective_friend_notification_intent)

    transactable.effective_friend_notification_intent
  end

  def percentage_source_entry_for(source_entries, missing_amount)
    source_entries.find { |entry| (entry[:principal_total].to_i + missing_amount.to_i).positive? } || source_entries.first
  end

  def source_allocation_issue_code(intent:, has_moi_entity:, missing_amount:)
    return "entity_allocation_mismatch" if intent == "loan"

    !has_moi_entity && missing_amount.positive? ? "missing_moi_allocation" : "entity_allocation_mismatch"
  end

  def source_allocation_issue_resolved?(intent:, issue_code:, transactable:, transaction_total:)
    return source_allocation_explained_by_return_percentages?(transactable, transaction_total) if %w[loan reimbursement].include?(intent)

    intent == "reimbursement" && issue_code == "missing_moi_allocation"
  end

  def source_allocation_explained_by_return_percentages?(transactable, transaction_total)
    implied_total = transactable.entity_transactions.select(&:is_payer?).sum do |entity_transaction|
      percentage = entity_transaction.loan_return_percentage.to_d
      return false unless percentage.positive?

      ((entity_transaction.price_to_be_returned.to_i.abs.to_d * 100) / percentage).round
    end

    implied_total == transaction_total.to_i.abs
  end

  def issues_for(row)
    issues = []
    issues << "installments_total_mismatch" if issue_enabled?("installments_total_mismatch") && row[:price] != row[:installments_sum]
    issues << "exchange_rows_total_mismatch" if issue_enabled?("exchange_rows_total_mismatch") && row[:exchange_return] && row[:price] != row[:exchange_rows_sum]
    issues << "stale_linked_source_rows" if issue_enabled?("stale_linked_source_rows") && row[:linked_source_rows].present?
    issues << "source_allocation_mismatch" if issue_enabled?("source_allocation_mismatch") && row[:source_allocation_rows].present?
    issues << "card_bound_bill_projection_mismatch" if issue_enabled?("card_bound_bill_projection_mismatch") && row[:card_bound_projection_rows].present?
    issues
  end

  def issue_enabled?(issue_code)
    issue_filter.blank? || issue_filter == issue_code
  end

  def linked_source_rows_enabled?
    issue_filter.blank? || %w[
      stale_linked_source_rows
      source_allocation_mismatch
    ].include?(issue_filter)
  end

  def source_allocation_enabled?
    issue_enabled?("source_allocation_mismatch")
  end

  def card_bound_projection_enabled?
    issue_enabled?("card_bound_bill_projection_mismatch")
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
    stale_card_bound_exchanges.reject { |exchange| exchange.cash_transaction_id == cash_transaction.id }
  end

  def stale_card_bound_exchanges
    return @stale_card_bound_exchanges if defined?(@stale_card_bound_exchanges)

    @stale_card_bound_exchanges = Exchange
                                  .monetary
                                  .card_bound
                                  .joins(:cash_transaction)
                                  .where(cash_transactions: { context_id: audit_context.id })
                                  .includes(:cash_transaction, entity_transaction: :entity)
                                  .to_a
    preload_card_bound_exchange_sources(@stale_card_bound_exchanges)
    @stale_card_bound_exchanges
  end

  def preload_card_bound_exchange_sources(exchanges)
    entity_transactions = exchanges.filter_map(&:entity_transaction)
    ActiveRecord::Associations::Preloader.new(records: entity_transactions, associations: :transactable).call

    card_transactions = entity_transactions.filter_map(&:transactable).grep(CardTransaction)
    ActiveRecord::Associations::Preloader.new(records: card_transactions, associations: :card_installments).call
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
    return return_flow_replay_diffs_for(payload, cash_transaction) if return_flow_replay_comparison?(payload, cash_transaction)

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

  def return_flow_replay_comparison?(payload, cash_transaction)
    return false unless cash_transaction.exchange_return? || cash_transaction.borrow_return?

    payload["type"] == "CardTransaction" || cash_transaction.shared_return_flow?
  end

  def return_flow_replay_diffs_for(payload, cash_transaction)
    attributes = return_flow_comparable_payload_attributes(payload)
    diffs = attributes.each_with_object({}) do |attribute, result|
      next unless payload.key?(attribute)

      local_value = normalized_return_flow_replay_value(attribute, cash_transaction.public_send(attribute), cash_transaction)
      payload_value = normalized_replay_value(attribute, payload[attribute])
      next if local_value == payload_value

      result[attribute] = { local: local_value, payload: payload_value }
    end

    installment_diffs = return_flow_replay_installment_diffs_for(payload, cash_transaction)
    diffs["cash_installments_attributes"] = installment_diffs if installment_diffs.present?
    diffs
  end

  def return_flow_comparable_payload_attributes(payload)
    return %w[price paid] if payload["type"] == "CardTransaction"

    %w[date month year price paid]
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

  def return_flow_replay_installment_diffs_for(payload, cash_transaction)
    payload_installments = Array(payload["cash_installments_attributes"])
    return [] if payload_installments.empty?

    local_installments = cash_transaction.cash_installments.index_by(&:number)
    payload_installments.filter_map do |payload_installment|
      number = payload_installment["number"].to_i
      local_installment = local_installments[number]
      next if local_installment.blank?

      diffs = %w[date month year price paid].each_with_object({}) do |attribute, result|
        next unless payload_installment.key?(attribute)

        local_value = normalized_return_flow_replay_value(attribute, local_installment.public_send(attribute), cash_transaction)
        payload_value = normalized_replay_value(attribute, payload_installment[attribute])
        next if local_value == payload_value

        result[attribute] = { local: local_value, payload: payload_value }
      end
      next if diffs.empty?

      { number:, diffs: }
    end
  end

  def normalized_return_flow_replay_value(attribute, value, cash_transaction)
    return value.to_i * return_flow_price_multiplier(cash_transaction) if attribute == "price"

    normalized_replay_value(attribute, value)
  end

  def return_flow_price_multiplier(cash_transaction)
    cash_transaction.exchange_return? ? -1 : 1
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
