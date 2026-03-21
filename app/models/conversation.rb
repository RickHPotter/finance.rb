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
  validates :assistant_owner, presence: true, if: :assistant?

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

  def self.find_or_create_assistant_between!(sender:, receiver:)
    for_users([ sender.id, receiver.id ]).assistant.find_by(assistant_owner: receiver) ||
      create_with_participants!(sender, receiver, kind: :assistant, assistant_owner: receiver)
  end

  def self.create_with_participants!(user1, user2, **attributes)
    create!(attributes).tap do |conversation|
      conversation.conversation_participants.create!(user: user1)
      conversation.conversation_participants.create!(user: user2)
    end
  end

  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  kind               :string           default("human"), not null, indexed => [assistant_owner_id]
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  assistant_owner_id :bigint           indexed, indexed => [kind]
#
# Indexes
#
#  index_conversations_on_assistant_owner_id           (assistant_owner_id)
#  index_conversations_on_kind_and_assistant_owner_id  (kind,assistant_owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (assistant_owner_id => users.id)
#
