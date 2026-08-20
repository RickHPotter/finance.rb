# frozen_string_literal: true

class Logic::Conversations::MessageInventory
  NOTIFICATION_ACTIONS = %w[create update destroy].freeze
  PAID_STATE_ACTIONS = %w[paid unpaid].freeze

  attr_reader :messages

  def initialize(messages: Message.order(:id))
    @messages = messages
  end

  def issues
    messages.flat_map { |message| payload_issues(message) + state_issues(message) }
  end

  private

  def payload_issues(message)
    return [] if message.headers.blank?

    payload = JSON.parse(message.headers)
    reasons = payload.is_a?(Hash) ? payload_reasons(payload) : [ "payload_not_an_object" ]
    issue_for(message, "invalid_message_payload", reasons)
  rescue JSON::ParserError
    issue_for(message, "invalid_message_payload", [ "malformed_json" ])
  end

  def payload_reasons(payload)
    case payload["version"]
    when nil
      []
    when "message_notification_v2"
      notification_reasons(payload)
    when "message_paid_state_v1"
      paid_state_reasons(payload)
    else
      [ "unsupported_version" ]
    end
  end

  def notification_reasons(payload)
    event = payload["event"]
    return [ "missing_event" ] unless event.is_a?(Hash)

    action = event["action"]
    reasons = []
    reasons << "invalid_notification_action" unless action.in?(NOTIFICATION_ACTIONS)
    reasons << "missing_replay" if action.in?(%w[create update]) && !payload["replay"].is_a?(Hash)
    reasons << "destroy_replay_present" if action == "destroy" && payload["replay"].present?
    reasons
  end

  def paid_state_reasons(payload)
    event = payload["event"]
    return [ "missing_event" ] unless event.is_a?(Hash)

    event["action"].in?(PAID_STATE_ACTIONS) ? [] : [ "invalid_paid_state_action" ]
  end

  def state_issues(message)
    reasons = []
    reasons << "human_with_action_facts" if inferred_kind(message) == "human" && action_facts?(message)
    reasons << "reverted_without_applied" if message.reverted_at.present? && message.applied_at.blank?
    reasons << "auto_applied_without_applied" if message.auto_applied? && message.applied_at.blank?
    reasons << "reverted_before_applied" if message.reverted_at.present? && message.applied_at.present? && message.reverted_at < message.applied_at
    reasons << "self_superseded" if message.superseded_by_id == message.id
    issue_for(message, "action_state_contradiction", reasons)
  end

  def inferred_kind(message)
    message.backfill_kind
  end

  def action_facts?(message)
    message.applied_at.present? || message.reverted_at.present? || message.auto_applied?
  end

  def issue_for(message, code, reasons)
    return [] if reasons.empty?

    [ Logic::Conversations::InventoryReport::Issue.new(code:, record_type: "Message", record_ids: [ message.id ], details: { reasons: }) ]
  end
end
