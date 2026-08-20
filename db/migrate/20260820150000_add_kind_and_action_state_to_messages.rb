# frozen_string_literal: true

class AddKindAndActionStateToMessages < ActiveRecord::Migration[8.1]
  class LegacyMessage < ActiveRecord::Base
    self.table_name = "messages"

    belongs_to :reference_transactable, polymorphic: true, optional: true
  end

  def up
    add_column :messages, :kind, :string
    add_column :messages, :action_state, :string
    add_index :messages, %i[kind action_state]

    LegacyMessage.reset_column_information
    LegacyMessage.find_each do |message|
      kind, payload_valid = classification_for(message)
      message.update_columns(kind:, action_state: action_state_for(message, kind:, payload_valid:))
    end
  end

  def down
    remove_index :messages, %i[kind action_state]
    remove_columns :messages, :kind, :action_state
  end

  private

  def classification_for(message)
    payload, payload_valid = parsed_payload(message.headers)
    payload_valid &&= valid_payload_shape?(payload)
    version = payload["version"] if payload.is_a?(Hash)
    action = payload["event"]["action"] if payload.is_a?(Hash) && payload["event"].is_a?(Hash)

    kind =
      if version == "message_paid_state_v1"
        "paid_state_sync"
      elsif version == "message_notification_v2"
        notification_kind(action)
      elsif message.headers.present?
        "transaction_notification"
      elsif reference_transactable_present?(message)
        "transaction_destroy_notification"
      else
        "human"
      end

    [ kind, payload_valid ]
  end

  def reference_transactable_present?(message)
    message.reference_transactable.present?
  rescue NameError
    false
  end

  def notification_kind(action)
    return "transaction_destroy_notification" if action == "destroy"
    return "transaction_notification" if action.in?(%w[create update])

    "human"
  end

  def parsed_payload(headers)
    return [ {}, true ] if headers.blank?

    payload = JSON.parse(headers)
    [ payload, payload.is_a?(Hash) ]
  rescue JSON::ParserError
    [ {}, false ]
  end

  def action_state_for(message, kind:, payload_valid:)
    return if kind == "human"
    return "unavailable" if contradictory_action_facts?(message)
    return "reverted" if message.reverted_at.present?
    return "accepted" if message.applied_at.present?
    return "expired" if message.superseded_by_id.present?
    return "unavailable" unless payload_valid

    "pending"
  end

  def valid_payload_shape?(payload)
    case payload["version"]
    when nil
      true
    when "message_notification_v2"
      valid_notification_payload?(payload)
    when "message_paid_state_v1"
      valid_paid_state_payload?(payload)
    else
      false
    end
  end

  def valid_notification_payload?(payload)
    return false unless payload["event"].is_a?(Hash)

    action = payload["event"]["action"]
    action.in?(%w[create update destroy]) &&
      valid_details?(payload) &&
      (!action.in?(%w[create update]) || payload["replay"].is_a?(Hash)) &&
      (action != "destroy" || payload["replay"].blank?)
  end

  def valid_paid_state_payload?(payload)
    payload["event"].is_a?(Hash) && payload["event"]["action"].in?(%w[paid unpaid]) && valid_details?(payload)
  end

  def valid_details?(payload)
    !payload["event"]["details"].present? || payload["event"]["details"].is_a?(Hash)
  end

  def contradictory_action_facts?(message)
    (message.reverted_at.present? && message.applied_at.blank?) ||
      (message.auto_applied? && message.applied_at.blank?) ||
      (message.reverted_at.present? && message.applied_at.present? && message.reverted_at < message.applied_at)
  end
end
