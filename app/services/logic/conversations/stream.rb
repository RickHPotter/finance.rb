# frozen_string_literal: true

class Logic::Conversations::Stream
  def self.for(conversation:, actor:, context:)
    raise Logic::Conversations::Policy::AccessDenied, :friendship_unavailable unless Logic::Conversations::Policy.stream_allowed?(conversation)

    Logic::Conversations::Policy.new(conversation:, actor:, context:).authorize!
    participant = conversation.participant_for!(actor)

    for_participant(conversation:, participant:)
  end

  def self.for_participant(conversation:, participant:)
    [ conversation, "participant", participant ]
  end

  def self.each_authorized(conversation)
    return enum_for(__method__, conversation) unless block_given?
    return unless Logic::Conversations::Policy.stream_allowed?(conversation)

    conversation.conversation_participants.find_each do |participant|
      yield for_participant(conversation:, participant:)
    end
  end
end
