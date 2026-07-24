# frozen_string_literal: true

class HealthCheck::Repairs::MisplacedExchangeIntentPlanner < HealthCheck::Repairs::BasePlanner
  def call
    row = live_row
    raise ActiveRecord::RecordNotFound if row.blank?
    return read_only("owner_only", references: references_for(row)) unless row[:source_user_id] == scope.user.id

    source = CashTransaction.find(row[:source_id])
    message_changes, message_warnings = changes_for_messages(row[:message_ids])
    changes = [
      change(
        record_type: "CashTransaction",
        record_id: source.id,
        attribute: "friend_notification_intent",
        before: source.friend_notification_intent,
        after: "reimbursement",
        metadata: { effective_before: source.effective_friend_notification_intent }
      ),
      *message_changes
    ]

    previewable(
      changes:,
      references: references_for(row),
      warnings: message_warnings
    )
  end

  private

  def live_row
    @live_row ||= Logic::MisplacedLoanExchangeAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      connected_user_id: scope.connected_user&.id
    ).call.find { |row| row[:source_id].to_i == finding_id }
  end

  def changes_for_messages(message_ids)
    warnings = []
    changes = Message.where(id: message_ids).order(:id).flat_map do |message|
      headers = JSON.parse(message.headers.to_s)
      intent_changes_for(message, headers)
    rescue JSON::ParserError
      warnings << { code: "invalid_message_headers", message_id: message.id }
      []
    end

    [ changes, warnings ]
  end

  def intent_changes_for(message, headers)
    [
      intent_change(message, headers, "intent"),
      intent_change(message, headers["replay"], "intent", prefix: "replay")
    ].compact
  end

  def intent_change(message, container, key, prefix: nil)
    return unless container.is_a?(Hash) && container.key?(key)
    return if container[key] == "reimbursement"

    change(
      record_type: "Message",
      record_id: message.id,
      attribute: [ prefix, key ].compact.join("."),
      before: container[key],
      after: "reimbursement",
      metadata: { conversation_id: message.conversation_id }
    )
  end

  def references_for(row)
    [
      {
        type: "CashTransaction",
        id: row[:source_id],
        role: "intent_source",
        user_id: row[:source_user_id]
      },
      {
        type: "Message",
        ids: Array(row[:message_ids]),
        role: "active_replay_messages",
        count: Array(row[:message_ids]).size
      }
    ]
  end
end
