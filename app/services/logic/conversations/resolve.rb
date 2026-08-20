# frozen_string_literal: true

class Logic::Conversations::Resolve
  class UnavailableError < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("Conversation unavailable: #{reason}")
    end
  end

  attr_reader :actor, :friendship, :kind, :scenario_key

  def self.call(...)
    new(...).call
  end

  def initialize(actor:, friendship:, kind:, scenario_key: nil)
    @actor = actor
    @friendship = friendship
    @kind = kind.to_s
    @scenario_key = scenario_key.presence
  end

  def call
    validate_kind!
    raise UnavailableError, :friendship_missing if friendship.blank?

    Friendship.transaction(requires_new: true) do
      friendship.lock!
      validate_friendship!
      validate_scenario!

      find_conversation || create_conversation!
    end
  rescue ActiveRecord::RecordNotUnique => e
    find_conversation || raise(e)
  end

  private

  def validate_kind!
    raise UnavailableError, :invalid_kind unless kind.in?(Conversation.kinds.keys)
  end

  def validate_friendship!
    raise UnavailableError, :actor_not_participant unless actor.id.in?(participant_user_ids)
    raise UnavailableError, :friendship_not_accepted unless friendship.accepted_state?
  end

  def validate_scenario!
    contexts = Context.where(user_id: participant_user_ids)
    contexts = scenario_key ? contexts.where(main: false, scenario_key:) : contexts.where(main: true)
    available_user_ids = contexts.order(:id).lock.pluck(:user_id).uniq.sort

    raise UnavailableError, :scenario_unavailable unless available_user_ids == participant_user_ids
  end

  def find_conversation
    conversation = conversation_scope.first
    return if conversation.blank?
    return conversation if conversation.conversation_participants.pluck(:user_id).sort == participant_user_ids

    raise UnavailableError, :participant_mismatch
  end

  def create_conversation!
    Conversation.new(friendship:, kind:, scenario_key:).tap do |conversation|
      participant_users.each { |user| conversation.conversation_participants.build(user:) }
      conversation.save!
    end
  end

  def conversation_scope
    Conversation.where(friendship:, kind:, scenario_key:)
  end

  def participant_users
    @participant_users ||= User.where(id: participant_user_ids).order(:id).to_a
  end

  def participant_user_ids
    @participant_user_ids ||= [ friendship.user_id, friendship.friend_id ].sort
  end
end
