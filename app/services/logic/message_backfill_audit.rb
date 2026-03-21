# frozen_string_literal: true

class Logic::MessageBackfillAudit
  def call
    {
      generated_at: Time.current.iso8601,
      counts: message_counts,
      messages: Message.includes(:conversation, :user, :reference_transactable).order(:id).map { |message| serialize_message(message) }
    }
  end

  private

  def message_counts
    Message.find_each.each_with_object(Hash.new(0)) do |message, counts|
      counts[message.backfill_kind] += 1
    end
  end

  def serialize_message(message)
    {
      id: message.id,
      conversation_id: message.conversation_id,
      user_id: message.user_id,
      reference_transactable_type: message.reference_transactable_type,
      reference_transactable_id: message.reference_transactable_id,
      headers_present: message.headers.present?,
      backfill_kind: message.backfill_kind,
      proposed_conversation_role: message.human_message? ? "human" : "assistant",
      proposed_conversation_key: proposed_conversation_key_for(message),
      current_conversation_kind: message.conversation.kind,
      current_assistant_owner_id: message.conversation.assistant_owner_id,
      created_at: message.created_at.iso8601
    }
  end

  def proposed_conversation_key_for(message)
    participants = message.conversation.users.order(:id).pluck(:id)

    if message.human_message?
      "human:#{participants.join('-')}"
    else
      receiver_id = (participants - [ message.user_id ]).first
      "assistant:user_#{receiver_id}:sender_#{message.user_id}"
    end
  end
end
