# frozen_string_literal: true

class Logic::MessageBackfillRunner # rubocop:disable Metrics/ClassLength
  attr_reader :dry_run

  def initialize(dry_run: true)
    @dry_run = dry_run
  end

  def call
    {
      dry_run:,
      moves:,
      rewrites:,
      processed_messages_count: messages.size,
      moved_messages_count: moves.size,
      rewritten_messages_count: rewrites.size
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

      action = payload.dig(:event, :action)
      rewritten_reference = rewritten_reference_transactable_for(message, action:)
      reference_rewritten = rewritten_reference_changed?(message, rewritten_reference)
      update_attributes = {
        body: "notification:#{action}",
        headers: payload.to_json,
        reference_transactable: rewritten_reference
      }

      message.update!(update_attributes) unless dry_run

      {
        message_id: message.id,
        action:,
        version: payload[:version],
        reference_rewritten:
      }
    end
  end

  def target_conversation_for(message)
    participants = message.conversation.users.to_a
    sender = participants.find { |user| user.id == message.user_id }
    receiver = participants.find { |user| user.id != message.user_id }
    return if sender.blank? || receiver.blank?

    scenario_key = message.conversation.scenario_key

    if message.human_message?
      Conversation.find_or_create_human_between!(sender, receiver, scenario_key:)
    else
      Conversation.find_or_create_assistant_between!(sender, receiver, scenario_key:)
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
        details: notification_details_for(message, replay_payload, transaction_type, receiver, action:)
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

      same_notification_chain?(candidate, message) && candidate.transaction_notification_message?
    end

    previous_notification_exists ? "update" : "create"
  end

  def same_notification_chain?(candidate, message)
    canonical_notification_reference_key(candidate) == canonical_notification_reference_key(message)
  end

  def notification_details_for(message, replay_payload, transaction_type, receiver, action:)
    return destroy_notification_details_for(message.reference_transactable, transaction_type) if action == "destroy"

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

  def destroy_notification_details_for(transaction, transaction_type)
    transaction_class = transaction_type.constantize
    installments_relation = transaction.present? ? transaction.installments.order(:number, :date) : []
    installments = normalize_installments(installments_relation.map { |installment| installment.slice(:number, :date, :price) })
    transaction_date = transaction&.date
    transaction_date = transaction_date.to_date.iso8601 if transaction_date.present?

    {
      transaction_label: transaction_class.human_attribute_name(:self),
      description: transaction&.description,
      date: transaction_date,
      reference_month_year: transaction&.month_year,
      price: transaction&.price,
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

  def rewritten_reference_transactable_for(message, action:)
    return message.reference_transactable unless action == "destroy"

    destroy_reference = message.reference_transactable
    return destroy_reference unless destroy_reference.is_a?(CashTransaction)

    parent_reference = destroy_reference.reference_transactable
    return destroy_reference unless parent_reference.is_a?(CashTransaction)
    return destroy_reference unless parent_reference.persisted? && !parent_reference.destroyed?

    parent_reference
  end

  def rewritten_reference_changed?(message, rewritten_reference)
    current_reference = message.reference_transactable
    return false if current_reference.blank? && rewritten_reference.blank?
    return true if current_reference.blank? || rewritten_reference.blank?

    current_reference.class.name != rewritten_reference.class.name || current_reference.id != rewritten_reference.id
  end

  def canonical_notification_reference_key(message)
    payload = message.replay_payload || {}
    reference = notification_reference_transactable_for(message, payload)
    return [ nil, nil ] if reference.blank?

    root_reference = reference_root_for(reference)
    [ root_reference.class.name, root_reference.id ]
  end

  def notification_reference_transactable_for(message, payload)
    return message.reference_transactable if message.reference_transactable.present?

    type = payload["type"]
    id = payload["id"]
    return if type.blank? || id.blank?

    type.constantize.find_by(id:)
  rescue NameError
    nil
  end

  def reference_root_for(reference)
    return reference.reference_root_transaction if reference.is_a?(CashTransaction)

    reference
  end
end
