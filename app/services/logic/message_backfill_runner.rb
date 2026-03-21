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
      moves:
    }
  end

  private

  def messages
    @messages ||= Message.includes(conversation: :users).order(:id).to_a
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
        target_kind: target_conversation.kind,
        assistant_owner_id: target_conversation.assistant_owner_id
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
      Conversation.find_or_create_assistant_between!(sender:, receiver:)
    end
  end
end
