# frozen_string_literal: true

class Conversation < ApplicationRecord
  # @extends ..................................................................
  enum :kind, { human: "human", assistant: "assistant" }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :assistant_owner, class_name: "User", optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :users, through: :conversation_participants
  has_many :messages, dependent: :destroy

  accepts_nested_attributes_for :conversation_participants, allow_destroy: true

  # @validations ..............................................................

  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :for_users, lambda { |user_ids|
    ids = Array(user_ids).uniq

    joins(:conversation_participants)
      .where(conversation_participants: { user_id: ids })
      .group("conversations.id")
      .having("COUNT(DISTINCT conversation_participants.user_id) = ?", ids.size)
  }

  # @additional_config ........................................................
  # @class_methods ............................................................
  def self.fast_create(user1, user2)
    create_with_participants!(user1, user2)
  end

  def self.find_or_create_human_between!(user1, user2)
    for_users([ user1.id, user2.id ]).human.first || create_with_participants!(user1, user2, kind: :human)
  end

  def self.find_or_create_assistant_between!(user1, user2)
    for_users([ user1.id, user2.id ]).assistant.order(:id).first || create_with_participants!(user1, user2, kind: :assistant)
  end

  def self.create_with_participants!(user1, user2, **attributes)
    create!(attributes).tap do |conversation|
      conversation.conversation_participants.create!(user: user1)
      conversation.conversation_participants.create!(user: user2)
    end
  end

  # @public_instance_methods ..................................................
  def friend_for(user)
    participants = users.loaded? ? users.target : users.to_a

    participants.find { |participant| participant.id != user.id }
  end

  def title_for(user)
    if human?
      friend_for(user)&.first_name
    else
      I18n.t("activerecord.attributes.conversation.assistant_with", name: friend_for(user)&.first_name)
    end
  end

  def unread_count_for(user)
    return messages.unread.where.not(user_id: user.id).count unless messages.loaded?

    messages.target.count { |message| message.read_at.nil? && message.user_id != user.id }
  end

  def latest_message
    return messages.max_by(&:created_at) if messages.loaded?

    messages.order(created_at: :desc).first
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id         :bigint           not null, primary key
#  kind       :string           default("human"), not null, indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_conversations_on_kind  (kind)
#
