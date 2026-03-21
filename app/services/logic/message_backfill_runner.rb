# frozen_string_literal: true

class Logic::MessageBackfillRunner
  attr_reader :dry_run

  def initialize(dry_run: true)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      processed_messages_count: messages.size,
      moved_messages_count: moves.size,
      rewritten_messages_count: rewrites.size,
      moves:,
      rewrites:
    }
  end

  private

  def messages
    @messages ||= Message.includes(:reference_transactable, conversation: :users).order(:id).to_a
  end

  def moves
    @moves ||= messages.filter_map do |message|
      original_conversation_id = message.conversation_id
      target_conversation = target_conversation_for(message)
      next if target_conversation.blank? || target_conversation.id == original_conversation_id

      message.update!(conversation: target_conversation) unless dry_run

      {
        message_id: message.id,
        from_conversation_id: original_conversation_id,
        to_conversation_id: target_conversation.id,
        backfill_kind: message.backfill_kind,
        target_kind: target_conversation.kind
      }
    end
  end

  def rewrites
    @rewrites ||= messages.filter_map do |message|
      next if message.human_message? || message.notification_payload_v2?

      payload = build_v2_payload_for(message)
      next if payload.blank?

      update_attributes = {
        body: "notification:#{payload.dig(:event, :action)}",
        headers: payload.to_json
      }

      message.update!(update_attributes) unless dry_run

      {
        message_id: message.id,
        action: payload.dig(:event, :action),
        version: payload[:version]
      }
    end
  end

  def target_conversation_for(message)
    participants = message.conversation.users.to_a
    sender = participants.find { |user| user.id == message.user_id }
    receiver = participants.find { |user| user.id != message.user_id }
    return if sender.blank? || receiver.blank?

    if message.human_message?
      Conversation.find_or_create_human_between!(sender, receiver)
    else
      Conversation.find_or_create_assistant_between!(sender, receiver)
    end
  end

  def build_v2_payload_for(message)
    participants = message.conversation.users.to_a
    receiver = participants.find { |user| user.id != message.user_id }
    return if receiver.blank?

    action = notification_action_for(message)
    return if action.blank?

    replay_payload = message.replay_payload
    transaction_type = replay_payload&.fetch("type", nil) || message.reference_transactable_type
    return if transaction_type.blank?

    {
      version: "message_notification_v2",
      event: {
        action:,
        receiver_first_name: receiver.first_name,
        transaction_type:,
        details: notification_details_for(message, replay_payload, transaction_type, receiver)
      },
      replay: action == "destroy" ? nil : replay_payload
    }
  end

  def notification_action_for(message)
    return "destroy" if message.transaction_destroy_notification_message?
    return if message.human_message?

    previous_notification_exists = messages.any? do |candidate|
      next false if candidate.id == message.id
      next false if candidate.conversation_id != message.conversation_id
      next false if candidate.user_id != message.user_id
      next false if candidate.created_at >= message.created_at

      same_reference_target?(candidate, message) && candidate.transaction_notification_message?
    end

    previous_notification_exists ? "update" : "create"
  end

  def same_reference_target?(candidate, message)
    candidate_payload = candidate.replay_payload || {}
    message_payload = message.replay_payload || {}

    candidate_type = candidate_payload["type"] || candidate.reference_transactable_type
    message_type = message_payload["type"] || message.reference_transactable_type
    candidate_id = candidate_payload["id"] || candidate.reference_transactable_id
    message_id = message_payload["id"] || message.reference_transactable_id

    candidate_type == message_type && candidate_id == message_id
  end

  def notification_details_for(message, replay_payload, transaction_type, receiver)
    transaction_class = transaction_type.constantize
    installments = installments_for(message, replay_payload, receiver)

    {
      transaction_label: transaction_class.human_attribute_name(:self),
      description: notification_description_for(message, replay_payload),
      date: notification_date_for(message, replay_payload),
      reference_month_year: notification_month_year_for(message, replay_payload),
      price: replay_payload&.fetch("price", nil) || installments.sum { |installment| installment[:price].to_i },
      installments_count: installments.size,
      installments:
    }
  end

  def notification_description_for(message, replay_payload)
    replay_payload&.fetch("description", nil) || message.reference_transactable&.description
  end

  def notification_date_for(message, replay_payload)
    return replay_payload["date"] if replay_payload&.key?("date")

    transactable_date = message.reference_transactable&.date
    transactable_date&.to_date&.iso8601
  end

  def notification_month_year_for(message, replay_payload)
    month = replay_payload&.fetch("month", nil) || message.reference_transactable&.month
    year = replay_payload&.fetch("year", nil) || message.reference_transactable&.year

    return RefMonthYear.new(month, year).month_year if month.present? && year.present?

    message.reference_transactable&.month_year
  end

  def installments_for(message, replay_payload, receiver)
    return normalize_installments(replay_payload["cash_installments_attributes"]) if replay_payload&.dig("cash_installments_attributes").present?

    transactable = message.reference_transactable
    return [] if transactable.blank?

    entity_transaction = transactable.entity_transactions.joins(:entity).find_by(entities: { entity_user_id: receiver.id })
    return [] if entity_transaction.blank?

    normalize_installments(entity_transaction.exchanges.order(:number, :date).map { |exchange| exchange.slice(:number, :date, :price) })
  end

  def normalize_installments(installments)
    Array(installments).map do |installment|
      {
        number: installment[:number] || installment["number"],
        date: extract_installment_date(installment),
        price: installment[:price] || installment["price"]
      }
    end
  end

  def extract_installment_date(installment)
    value = installment[:date] || installment["date"]
    value.respond_to?(:iso8601) ? value.iso8601 : value
  end
end
