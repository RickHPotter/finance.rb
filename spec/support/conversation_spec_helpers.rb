# frozen_string_literal: true

module ConversationSpecHelpers
  def resolve_human_conversation(actor, friend, scenario_key: nil)
    resolve_conversation(actor:, friend:, kind: :human, scenario_key:)
  end

  def resolve_assistant_conversation(actor, friend, scenario_key: nil)
    resolve_conversation(actor:, friend:, kind: :assistant, scenario_key:)
  end

  def conversation_scope_for(actor, friend)
    Conversation.where(friendship: actor.friendship_with(friend))
  end

  private

  def resolve_conversation(actor:, friend:, kind:, scenario_key:)
    Logic::Conversations::Resolve.call(actor:, friendship: actor.friendship_with(friend), kind:, scenario_key:)
  end
end

RSpec.configure do |config|
  config.include ConversationSpecHelpers
end
