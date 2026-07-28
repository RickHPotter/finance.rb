# frozen_string_literal: true

class Audit::Rollback::Impact
  attr_reader :owner_contexts, :earliest_dates, :cash_transaction_ids, :card_transaction_ids,
              :user_bank_account_ids, :user_card_ids, :cash_category_ids, :card_category_ids,
              :cash_entity_ids, :card_entity_ids

  def initialize(preview:)
    @owner_contexts = Set.new
    @earliest_dates = {}
    @cash_transaction_ids = Set.new
    @card_transaction_ids = Set.new
    @user_bank_account_ids = Set.new
    @user_card_ids = Set.new
    @cash_category_ids = Set.new
    @card_category_ids = Set.new
    @cash_entity_ids = Set.new
    @card_entity_ids = Set.new
    preview.rows.each { |row| capture_row(row) }
  end

  def capture_transaction(record)
    return if record.nil?

    if record.is_a?(CashTransaction)
      capture_cash_transaction(record)
    else
      capture_card_transaction(record)
    end
  end

  private

  def capture_cash_transaction(record)
    cash_transaction_ids << record.id
    user_bank_account_ids << record.user_bank_account_id if record.user_bank_account_id
    cash_category_ids.merge(record.category_transactions.pluck(:category_id))
    cash_entity_ids.merge(record.entity_transactions.pluck(:entity_id))
  end

  def capture_card_transaction(record)
    card_transaction_ids << record.id
    user_card_ids << record.user_card_id if record.user_card_id
    card_category_ids.merge(record.category_transactions.pluck(:category_id))
    card_entity_ids.merge(record.entity_transactions.pluck(:entity_id))
  end

  def capture_row(row)
    owner_contexts << [ row.owner_id, row.context_id ]
    states = [ row.before_state, row.expected_after_state, row.current_state ].compact
    states.each { |state| capture_state(row, state) }
  end

  def capture_state(row, state)
    capture_transaction_identity(row, state)
    capture_routing_ids(state)
    capture_date(row.context_id, state)
  end

  def capture_transaction_identity(row, state)
    case row.record_type
    when "CashTransaction" then cash_transaction_ids << row.item_id
    when "CardTransaction" then card_transaction_ids << row.item_id
    when "CashInstallment" then cash_transaction_ids << state["cash_transaction_id"] if state["cash_transaction_id"]
    when "CardInstallment" then card_transaction_ids << state["card_transaction_id"] if state["card_transaction_id"]
    end
  end

  def capture_routing_ids(state)
    user_bank_account_ids << state["user_bank_account_id"] if state["user_bank_account_id"]
    user_card_ids << state["user_card_id"] if state["user_card_id"]
  end

  def capture_date(context_id, state)
    date = parse_date(state)
    return if context_id.nil? || date.nil?

    @earliest_dates[context_id] = [ earliest_dates[context_id], date ].compact.min
  end

  def parse_date(state)
    return Time.zone.parse(state["date"].to_s) if state["date"].present?
    return if state["year"].blank? || state["month"].blank?

    Time.zone.local(state["year"].to_i, state["month"].to_i, 1)
  rescue ArgumentError, TypeError
    nil
  end
end
