# frozen_string_literal: true

class Logic::Conversations::Inventory
  attr_reader :conversation_scope, :message_scope

  def initialize(conversation_scope: Conversation.all, message_scope: Message.all)
    @conversation_scope = conversation_scope
    @message_scope = message_scope
  end

  def call
    Logic::Conversations::InventoryReport.new(
      conversation_count: conversations.count,
      message_count: messages.count,
      issues: conversation_issues + message_issues
    )
  end

  private

  def conversations
    @conversations ||= if conversation_scope.respond_to?(:includes)
                         conversation_scope.includes(:conversation_participants).order(:id).to_a
                       else
                         Array(conversation_scope).sort_by(&:id)
                       end
  end

  def messages
    @messages ||= message_scope.respond_to?(:order) ? message_scope.order(:id).to_a : Array(message_scope).sort_by(&:id)
  end

  def conversation_issues
    participant_count_issues + duplicate_participant_issues + duplicate_thread_issues + friendship_issues + scenario_issues
  end

  def participant_count_issues
    conversations.filter_map do |conversation|
      participants = conversation.conversation_participants
      next if participants.size == 2

      issue(
        "invalid_participant_count",
        "Conversation",
        [ conversation.id ],
        participant_count: participants.size,
        user_ids: participants.map(&:user_id)
      )
    end
  end

  def duplicate_participant_issues
    conversations.flat_map do |conversation|
      conversation.conversation_participants.group_by(&:user_id).filter_map do |user_id, participants|
        next unless participants.many?

        issue(
          "duplicate_participant",
          "ConversationParticipant",
          participants.map(&:id).sort,
          conversation_id: conversation.id,
          user_id:,
          count: participants.count
        )
      end
    end
  end

  def duplicate_thread_issues
    pair_conversations.group_by { |conversation| canonical_key(conversation) }.filter_map do |key, rows|
      next unless rows.many?

      user_ids, kind, scenario_key = key
      issue(
        "duplicate_canonical_thread",
        "Conversation",
        rows.map(&:id).sort,
        user_ids:,
        kind:,
        scenario_key: scenario_key || "main"
      )
    end
  end

  def friendship_issues
    pair_conversations.filter_map { |conversation| friendship_issue_for(conversation) }
  end

  def friendship_issue_for(conversation)
    user_ids = participant_user_ids(conversation)
    expected_friendship = friendships_by_pair[user_ids]

    return issue("missing_friendship", "Conversation", [ conversation.id ], user_ids:, friendship_id: nil, friendship_state: nil) if expected_friendship.nil?

    unless expected_friendship.accepted_state?
      return issue(
        "friendship_not_accepted",
        "Conversation",
        [ conversation.id ],
        user_ids:,
        friendship_id: expected_friendship.id,
        friendship_state: expected_friendship.state
      )
    end

    if conversation.friendship_id.nil?
      return issue(
        "unassigned_friendship",
        "Conversation",
        [ conversation.id ],
        user_ids:,
        expected_friendship_id: expected_friendship.id
      )
    end
    return if conversation.friendship_id == expected_friendship.id

    issue(
      "friendship_mismatch",
      "Conversation",
      [ conversation.id ],
      user_ids:,
      friendship_id: conversation.friendship_id,
      expected_friendship_id: expected_friendship.id
    )
  end

  def scenario_issues
    pair_conversations.filter_map do |conversation|
      missing_user_ids = participant_user_ids(conversation).reject do |user_id|
        context_keys.include?([ user_id, conversation.scenario_key ])
      end
      next if missing_user_ids.empty?

      issue(
        "missing_scenario",
        "Conversation",
        [ conversation.id ],
        scenario_key: conversation.scenario_key || "main",
        missing_user_ids:
      )
    end
  end

  def pair_conversations
    @pair_conversations ||= conversations.select { |conversation| participant_user_ids(conversation).size == 2 }
  end

  def participant_user_ids(conversation)
    conversation.conversation_participants.map(&:user_id).uniq.sort
  end

  def canonical_key(conversation)
    [ participant_user_ids(conversation), conversation.kind, conversation.scenario_key ]
  end

  def friendships_by_pair
    @friendships_by_pair ||= Friendship.order(:id).each_with_object({}) do |friendship, rows|
      rows[[ friendship.user_id, friendship.friend_id ].sort] ||= friendship
    end
  end

  def context_keys
    @context_keys ||= Context.pluck(:user_id, :scenario_key, :main).to_set do |user_id, scenario_key, main|
      [ user_id, main ? nil : scenario_key ]
    end
  end

  def message_issues
    Logic::Conversations::MessageInventory.new(messages:).issues
  end

  def issue(code, record_type, record_ids, details)
    Logic::Conversations::InventoryReport::Issue.new(code:, record_type:, record_ids:, details:)
  end
end
