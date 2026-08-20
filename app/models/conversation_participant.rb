# frozen_string_literal: true

class ConversationParticipant < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :conversation
  belongs_to :user
  belongs_to :last_read_message, class_name: "Message", optional: true

  # @validations ..............................................................
  validates :user_id, uniqueness: { scope: :conversation_id }
  validate :user_belongs_to_canonical_friendship
  validate :last_read_message_belongs_to_conversation
  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :active, -> { where(archived_at: nil) }
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def archived?
    archived_at.present?
  end

  def muted?
    muted_at.present?
  end

  def unread_messages
    conversation.messages
                .latest
                .where.not(user_id:)
                .where("messages.id > ?", last_read_message_id || 0)
  end

  def unread_count
    return unread_messages.count unless conversation.messages.loaded?

    conversation.messages.target.count do |message|
      message.user_id != user_id && message.superseded_by_id.nil? && message.id > (last_read_message_id || 0)
    end
  end

  def advance_read_cursor_to!(message)
    return if message.blank?
    raise ArgumentError, "Message belongs to another conversation" if message.conversation_id != conversation_id

    with_lock do
      reload
      update!(last_read_message: message) if last_read_message_id.nil? || last_read_message_id < message.id
    end
  end
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def user_belongs_to_canonical_friendship
    return if conversation&.friendship.blank?
    return if user_id.in?([ conversation.friendship.user_id, conversation.friendship.friend_id ])

    errors.add(:user, :invalid)
  end

  def last_read_message_belongs_to_conversation
    return if last_read_message.blank? || last_read_message.conversation_id == conversation_id

    errors.add(:last_read_message, :invalid)
  end
end

# == Schema Information
#
# Table name: conversation_participants
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  archived_at          :datetime
#  muted_at             :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  conversation_id      :bigint           not null, indexed, uniquely indexed => [user_id]
#  last_read_message_id :bigint           indexed
#  user_id              :bigint           not null, uniquely indexed => [conversation_id], indexed
#
# Indexes
#
#  index_conversation_participants_on_conversation_id       (conversation_id)
#  index_conversation_participants_on_last_read_message_id  (last_read_message_id)
#  index_conversation_participants_on_membership            (conversation_id,user_id) UNIQUE
#  index_conversation_participants_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (last_read_message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
