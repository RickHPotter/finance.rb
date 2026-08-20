# frozen_string_literal: true

class ConversationParticipant < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :conversation
  belongs_to :user

  # @validations ..............................................................
  validates :user_id, uniqueness: { scope: :conversation_id }
  validate :user_belongs_to_canonical_friendship
  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def user_belongs_to_canonical_friendship
    return if conversation&.friendship.blank?
    return if user_id.in?([ conversation.friendship.user_id, conversation.friendship.friend_id ])

    errors.add(:user, :invalid)
  end
end

# == Schema Information
#
# Table name: conversation_participants
# Database name: primary
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null, indexed, uniquely indexed => [user_id]
#  user_id         :bigint           not null, uniquely indexed => [conversation_id], indexed
#
# Indexes
#
#  index_conversation_participants_on_conversation_id  (conversation_id)
#  index_conversation_participants_on_membership       (conversation_id,user_id) UNIQUE
#  index_conversation_participants_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
