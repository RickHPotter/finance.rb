# frozen_string_literal: true

class Logic::Conversations::RevokeAccess
  attr_reader :friendship

  def self.call(...)
    new(...).call
  end

  def initialize(friendship:)
    @friendship = friendship
  end

  def call
    friendship.conversations.find_each do |conversation|
      conversation.messages.where(action_state: %w[pending failed]).find_each do |message|
        revoke_message!(conversation, message)
      end
    end
  end

  def broadcast
    friendship.conversations.find_each do |conversation|
      broadcast_conversation_revocation(conversation)
    end
  end

  private

  def broadcast_conversation_revocation(conversation)
    Turbo::StreamsChannel.broadcast_remove_to(conversation, target: "center_container")
  rescue StandardError => e
    Rails.error.report(e, handled: true, severity: :warning, context: { conversation_id: conversation.id, component: self.class.name })
  end

  def revoke_message!(conversation, message)
    recipient = conversation.friend_for(message.user)
    context = recipient_context(conversation, recipient)

    Logic::Messages::Transition.call(message, :unavailable)
    record_action!(conversation:, message:, recipient:, context:) if recipient.present? && context.present?
  end

  def recipient_context(conversation, recipient)
    return if recipient.blank?

    if conversation.scenario_key.present?
      recipient.contexts.active.find_by(main: false, scenario_key: conversation.scenario_key)
    else
      recipient.contexts.active.find_by(main: true)
    end
  end

  def record_action!(conversation:, message:, recipient:, context:)
    MessageAction.create!(
      message:,
      conversation:,
      friendship:,
      actor: recipient,
      friend: message.user,
      recipient_context: context,
      scenario_key: conversation.scenario_key,
      action: message.paid_state_sync_message? ? :acknowledge : :apply,
      initiator: :system,
      outcome: :denied,
      resulting_state: message.workflow_state,
      error_code: :friendship_unavailable,
      metadata: { "friendship_state" => friendship.state }
    )
  end
end
