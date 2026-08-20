# frozen_string_literal: true

class Logic::Conversations::Policy
  class AccessDenied < ActiveRecord::RecordNotFound
    attr_reader :reason

    def initialize(reason)
      @reason = reason.to_sym
      super("Conversation access denied: #{reason}")
    end
  end

  attr_reader :conversation, :actor, :context

  def self.scope(user:, context:)
    user.conversations
        .joins(:friendship)
        .merge(Friendship.accepted_state)
        .for_scenario(context.scenario_key)
  end

  def self.stream_allowed?(conversation)
    Friendship.accepted_state.exists?(id: conversation.friendship_id)
  end

  def initialize(conversation:, actor:, context:)
    @conversation = conversation
    @actor = actor
    @context = context
  end

  def failure_code
    return :friendship_unavailable unless friendship&.accepted_state?
    return :wrong_recipient unless participant?

    :wrong_context unless context_matches?
  end

  def authorize!
    reason = failure_code
    return if reason.blank?

    raise AccessDenied, reason
  end

  def with_access
    raise AccessDenied, :friendship_unavailable if friendship.blank?

    friendship.with_lock do
      friendship.reload
      authorize!
      yield
    end
  end

  def with_friendship_lock(&)
    return yield if friendship.blank?

    friendship.with_lock do
      friendship.reload
      yield
    end
  end

  private

  def friendship
    @friendship ||= conversation.friendship
  end

  def participant?
    conversation.conversation_participants.where(user_id: actor&.id).exists?
  end

  def context_matches?
    return false unless context&.user_id == actor&.id

    if conversation.scenario_key.present?
      !context.main? && context.scenario_key == conversation.scenario_key
    else
      context.main?
    end
  end
end
