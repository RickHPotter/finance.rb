# frozen_string_literal: true

class Logic::ExchangeBackfillAudit # rubocop:disable Metrics/ClassLength
  attr_reader :users

  def initialize(user_a:, user_b:)
    @users = [ user_a, user_b ]
  end

  def call
    {
      generated_at: Time.current.iso8601,
      users: users.map { |user| serialize_user(user) },
      cases: root_transactions.map { |transaction| serialize_case(transaction) }
    }
  end

  private

  def root_transactions
    CashTransaction.includes(
      :categories,
      :cash_installments,
      entity_transactions: %i[entity exchanges]
    ).where(user: users, reference_transactable: nil).order(:created_at).select do |transaction|
      transaction.categories.pluck(:category_name).include?("EXCHANGE") && counterpart_user_for(transaction).present?
    end
  end

  def serialize_case(source_transaction)
    counterpart_user = counterpart_user_for(source_transaction)
    receiver_reference = counterpart_user.cash_transactions.includes(
      :categories,
      :cash_installments,
      entity_transactions: %i[entity exchanges]
    ).find_by(reference_transactable: source_transaction)

    related_messages = messages_for(source_transaction, receiver_reference)
    latest_active_message = related_messages.find { |message| message.superseded_by_id.nil? }
    latest_headers = parse_headers(latest_active_message)

    {
      source_transaction: serialize_cash_transaction(source_transaction),
      counterpart_user: serialize_user(counterpart_user),
      receiver_reference_transaction: serialize_cash_transaction(receiver_reference),
      latest_active_message: serialize_message(latest_active_message, latest_headers),
      message_history: related_messages.map { |message| serialize_message(message) },
      snapshot_diff: compare_snapshot_to_transaction(latest_headers, receiver_reference),
      suggested_intent: suggested_intent(receiver_reference),
      needs_review: true,
      manual_intent: nil
    }
  end

  def counterpart_user_for(transaction)
    transaction.entity_transactions.find do |entity_transaction|
      entity_user = entity_transaction.entity.entity_user

      entity_transaction.exchanges_count.positive? && users.include?(entity_user) && entity_user != transaction.user
    end&.entity&.entity_user
  end

  def messages_for(source_transaction, receiver_reference)
    Message.includes(:user).where(reference_transactable: [ source_transaction, receiver_reference ].compact).order(:created_at)
  end

  def compare_snapshot_to_transaction(headers, transaction)
    return nil if headers.blank? || transaction.blank?

    snapshot = normalized_snapshot(headers)
    current = normalized_cash_transaction(transaction)

    snapshot.each_with_object({}) do |(key, value), diff|
      next if value == current[key]

      diff[key] = { snapshot: value, current: current[key] }
    end
  end

  def suggested_intent(transaction)
    return "missing_receiver_transaction" if transaction.blank?

    category_names = transaction.categories.pluck(:category_name)

    if category_names.include?("BORROW RETURN") || category_names.include?("EXCHANGE RETURN")
      "reimbursement_candidate"
    elsif category_names.include?("EXCHANGE")
      "loan_candidate"
    end
  end

  def normalized_snapshot(headers)
    {
      description: headers["description"],
      price: headers["price"],
      date: normalize_date(headers["date"]),
      month: headers["month"],
      year: headers["year"],
      category_id: headers["category_ids"],
      entity_id: headers["entity_ids"],
      cash_installments_attributes: normalize_installment_rows(headers["cash_installments_attributes"]),
      entity_transactions_attributes: normalize_entity_transaction_rows(headers["entity_transactions_attributes"])
    }
  end

  def normalized_cash_transaction(transaction)
    {
      description: transaction.description,
      price: transaction.price,
      date: transaction.date&.to_date&.iso8601,
      month: transaction.month,
      year: transaction.year,
      category_id: transaction.categories.first&.id,
      entity_id: transaction.entities.first&.id,
      cash_installments_attributes: normalize_installment_rows(transaction.cash_installments.order(:number, :date).map do |installment|
        installment.slice(:number, :price, :date, :month, :year)
      end),
      entity_transactions_attributes: normalize_entity_transaction_rows(transaction.entity_transactions.order(:id).map do |entity_transaction|
        {
          price: entity_transaction.price,
          price_to_be_returned: entity_transaction.price_to_be_returned,
          entity_id: entity_transaction.entity_id,
          exchanges_count: entity_transaction.exchanges_count,
          exchanges_attributes: entity_transaction.exchanges.order(:number, :date).map do |exchange|
            exchange.slice(:number, :price, :date, :month, :year)
          end
        }
      end)
    }
  end

  def normalize_installment_rows(rows)
    Array(rows).map do |row|
      row = row.with_indifferent_access

      {
        number: row[:number],
        price: row[:price],
        date: normalize_date(row[:date]),
        month: row[:month],
        year: row[:year]
      }
    end
  end

  def normalize_entity_transaction_rows(rows)
    Array(rows).map do |row|
      row = row.with_indifferent_access

      {
        price: row[:price],
        price_to_be_returned: row[:price_to_be_returned],
        entity_id: row[:entity_id],
        exchanges_count: row[:exchanges_count],
        exchanges_attributes: normalize_installment_rows(row[:exchanges_attributes])
      }
    end
  end

  def normalize_date(value)
    return if value.blank?

    value.to_date.iso8601
  rescue NoMethodError, ArgumentError
    value.to_s
  end

  def parse_headers(message)
    return if message&.headers.blank?

    JSON.parse(message.headers)
  rescue JSON::ParserError
    { "_invalid_json" => message.headers }
  end

  def serialize_cash_transaction(transaction) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return if transaction.blank?

    {
      id: transaction.id,
      user_id: transaction.user_id,
      reference_transactable_type: transaction.reference_transactable_type,
      reference_transactable_id: transaction.reference_transactable_id,
      description: transaction.description,
      price: transaction.price,
      date: transaction.date&.to_date&.iso8601,
      month: transaction.month,
      year: transaction.year,
      category_names: transaction.categories.pluck(:category_name),
      entity_transactions: transaction.entity_transactions.order(:id).map do |entity_transaction|
        {
          id: entity_transaction.id,
          entity_id: entity_transaction.entity_id,
          entity_name: entity_transaction.entity.entity_name,
          entity_user_id: entity_transaction.entity.entity_user_id,
          price: entity_transaction.price,
          price_to_be_returned: entity_transaction.price_to_be_returned,
          exchanges_count: entity_transaction.exchanges_count,
          exchanges: entity_transaction.exchanges.order(:number, :date).map do |exchange|
            {
              id: exchange.id,
              number: exchange.number,
              price: exchange.price,
              date: exchange.date&.to_date&.iso8601,
              month: exchange.month,
              year: exchange.year,
              cash_transaction_id: exchange.cash_transaction_id
            }
          end
        }
      end,
      cash_installments: transaction.cash_installments.order(:number, :date).map do |installment|
        {
          id: installment.id,
          number: installment.number,
          price: installment.price,
          date: installment.date&.to_date&.iso8601,
          month: installment.month,
          year: installment.year
        }
      end
    }
  end

  def serialize_message(message, headers = nil)
    return if message.blank?

    {
      id: message.id,
      user_id: message.user_id,
      superseded_by_id: message.superseded_by_id,
      reference_transactable_type: message.reference_transactable_type,
      reference_transactable_id: message.reference_transactable_id,
      created_at: message.created_at.iso8601,
      headers: headers || parse_headers(message)
    }
  end

  def serialize_user(user)
    {
      id: user.id,
      first_name: user.first_name,
      email: user.email
    }
  end
end
