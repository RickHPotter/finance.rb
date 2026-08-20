# frozen_string_literal: true

class Logic::Conversations::CanonicalBackfill
  class StalePlanError < StandardError; end

  Action = Data.define(:canonical_conversation_id, :duplicate_conversation_ids, :friendship_id, :kind, :scenario_key, :message_ids)

  Result = Data.define(:status, :actions, :issues) do
    def applied?
      status == "applied"
    end

    def to_text
      lines = [ "Canonical conversation backfill: #{status}", "Actions: #{actions.count}", "Inventory issues: #{issues.count}" ]
      actions.each do |action|
        lines << "conversation=#{action.canonical_conversation_id} friendship=#{action.friendship_id} kind=#{action.kind} " \
                 "scenario=#{action.scenario_key || 'main'} merged=#{action.duplicate_conversation_ids.join(',')} " \
                 "messages=#{action.message_ids.join(',')}"
      end
      issues.each do |issue|
        lines << "skipped/reported [#{issue.code}] #{issue.record_type} ids=#{issue.record_ids.join(',')}"
      end
      lines.join("\n")
    end
  end

  attr_reader :apply, :conversation_scope, :message_scope

  def initialize(apply: false, conversation_scope: Conversation.all, message_scope: Message.all)
    @apply = apply
    @conversation_scope = conversation_scope
    @message_scope = message_scope
  end

  def call
    planned_actions = actions
    return result("planned", planned_actions) unless apply

    applied_actions = apply_actions!(planned_actions)
    result("applied", applied_actions)
  end

  private

  def conversations
    @conversations ||= conversation_scope.includes(:conversation_participants).order(:id).to_a
  end

  def inventory_report
    @inventory_report ||= Logic::Conversations::Inventory.new(conversation_scope:, message_scope:).call
  end

  def actions
    eligible_conversations.group_by { |conversation| canonical_key(conversation) }.values.filter_map do |rows|
      canonical = rows.min_by(&:id)
      duplicates = rows.without(canonical).sort_by(&:id)
      canonical_friendship = friendship_for(canonical)
      next if duplicates.empty? && canonical.friendship_id == canonical_friendship.id

      Action.new(
        canonical_conversation_id: canonical.id,
        duplicate_conversation_ids: duplicates.map(&:id),
        friendship_id: canonical_friendship.id,
        kind: canonical.kind,
        scenario_key: canonical.scenario_key,
        message_ids: Message.where(conversation_id: duplicates.map(&:id)).order(:id).ids
      )
    end.sort_by(&:canonical_conversation_id)
  end

  def eligible_conversations
    conversations.select { |conversation| eligible_conversation?(conversation) }
  end

  def eligible_conversation?(conversation)
    participants = conversation.conversation_participants
    participants.size == 2 &&
      participant_user_ids(conversation).size == 2 &&
      friendship_for(conversation)&.accepted_state? &&
      scenario_present_for_both?(conversation)
  end

  def canonical_key(conversation)
    [ friendship_for(conversation).id, conversation.kind, conversation.scenario_key ]
  end

  def friendship_for(conversation)
    friendships_by_pair[participant_user_ids(conversation)]
  end

  def participant_user_ids(conversation)
    conversation.conversation_participants.map(&:user_id).uniq.sort
  end

  def friendships_by_pair
    @friendships_by_pair ||= Friendship.order(:id).each_with_object({}) do |friendship, rows|
      rows[[ friendship.user_id, friendship.friend_id ].sort] ||= friendship
    end
  end

  def scenario_present_for_both?(conversation)
    participant_user_ids(conversation).all? { |user_id| context_keys.include?([ user_id, conversation.scenario_key ]) }
  end

  def context_keys
    @context_keys ||= Context.pluck(:user_id, :scenario_key, :main).to_set do |user_id, scenario_key, main|
      [ user_id, main ? nil : scenario_key ]
    end
  end

  def apply_actions!(planned_actions)
    ApplicationRecord.transaction do
      Friendship.where(id: planned_actions.map(&:friendship_id)).order(:id).lock.load
      Conversation.where(id: planned_actions.flat_map { |action| [ action.canonical_conversation_id, *action.duplicate_conversation_ids ] }).order(:id).lock.load
      reset_plan!
      locked_actions = actions
      raise StalePlanError unless locked_actions == planned_actions

      locked_actions.each { |action| apply_action!(action) }
      locked_actions
    end
  end

  def apply_action!(action)
    canonical = Conversation.find(action.canonical_conversation_id)
    duplicates = Conversation.where(id: action.duplicate_conversation_ids).order(:id)

    Message.where(conversation_id: action.duplicate_conversation_ids).update_all(conversation_id: canonical.id)
    duplicates.each(&:destroy!)
    canonical.update!(friendship_id: action.friendship_id) if canonical.friendship_id != action.friendship_id
  end

  def reset_plan!
    @conversations = nil
    @friendships_by_pair = nil
  end

  def result(status, planned_actions)
    Result.new(status:, actions: planned_actions, issues: inventory_report.issues)
  end
end
