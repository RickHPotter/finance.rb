# frozen_string_literal: true

class MessageAction < ApplicationRecord
  # @extends ..................................................................
  ACTIONS = %w[apply acknowledge reject revert].freeze
  INITIATORS = %w[manual automatic system].freeze
  OUTCOMES = %w[succeeded failed denied idempotent].freeze
  ERROR_CODES = %w[
    unavailable friendship_unavailable wrong_recipient wrong_context superseded invalid_payload unsupported_action
    local_reference_unavailable local_reference_changed wrong_target unsafe_destroy paid_history state_unavailable
    validation_failed persistence_failed
  ].freeze

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  enum :action, ACTIONS.index_by(&:itself), prefix: true, validate: true
  enum :initiator, INITIATORS.index_by(&:itself), prefix: true, validate: true
  enum :outcome, OUTCOMES.index_by(&:itself), prefix: true, validate: true
  enum :resulting_state, Message::ACTION_STATES, prefix: :resulting, validate: true

  # @relationships ............................................................
  belongs_to :message
  belongs_to :conversation
  belongs_to :friendship
  belongs_to :actor, class_name: "User"
  belongs_to :friend, class_name: "User"
  belongs_to :recipient_context, class_name: "Context"
  belongs_to :audit_operation, optional: true

  # @validations ..............................................................
  validates :action, :initiator, :outcome, :resulting_state, presence: true
  validates :error_code, inclusion: { in: ERROR_CODES }, allow_nil: true
  validate :metadata_within_size_limit

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def readonly?
    persisted?
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  private

  def metadata_within_size_limit
    return if metadata.to_json.bytesize <= 16.kilobytes

    errors.add(:metadata, :too_long, count: 16.kilobytes)
  end
end

# == Schema Information
#
# Table name: message_actions
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  action               :string           not null, uniquely indexed => [message_id]
#  error_code           :string
#  initiator            :string           not null
#  metadata             :jsonb            not null
#  outcome              :string           not null
#  resulting_state      :string           not null
#  scenario_key         :uuid
#  created_at           :datetime         not null, indexed => [actor_id], indexed => [conversation_id], indexed => [recipient_context_id]
#  actor_id             :bigint           not null, indexed, indexed => [created_at]
#  audit_operation_id   :uuid             indexed
#  conversation_id      :bigint           not null, indexed, indexed => [created_at]
#  friend_id            :bigint           not null, indexed
#  friendship_id        :bigint           not null, indexed
#  message_id           :bigint           not null, indexed, uniquely indexed => [action]
#  recipient_context_id :bigint           not null, indexed, indexed => [created_at]
#
# Indexes
#
#  index_message_actions_on_actor_id                             (actor_id)
#  index_message_actions_on_actor_id_and_created_at              (actor_id,created_at)
#  index_message_actions_on_audit_operation_id                   (audit_operation_id)
#  index_message_actions_on_conversation_id                      (conversation_id)
#  index_message_actions_on_conversation_id_and_created_at       (conversation_id,created_at)
#  index_message_actions_on_friend_id                            (friend_id)
#  index_message_actions_on_friendship_id                        (friendship_id)
#  index_message_actions_on_message_id                           (message_id)
#  index_message_actions_on_recipient_context_id                 (recipient_context_id)
#  index_message_actions_on_recipient_context_id_and_created_at  (recipient_context_id,created_at)
#  index_message_actions_on_successful_effect                    (message_id,action) UNIQUE WHERE ((outcome)::text = 'succeeded'::text)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => restrict
#  fk_rails_...  (audit_operation_id => audit_operations.id) ON DELETE => restrict
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => restrict
#  fk_rails_...  (friend_id => users.id) ON DELETE => restrict
#  fk_rails_...  (friendship_id => friendships.id) ON DELETE => restrict
#  fk_rails_...  (message_id => messages.id) ON DELETE => restrict
#  fk_rails_...  (recipient_context_id => contexts.id) ON DELETE => restrict
#
