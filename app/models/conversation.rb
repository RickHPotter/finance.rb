# frozen_string_literal: true

class Conversation < ApplicationRecord
  # @extends ..................................................................
  enum :kind, { human: "human", assistant: "assistant" }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_readonly :public_id

  # @relationships ............................................................
  belongs_to :friendship, optional: true
  has_many :conversation_participants, dependent: :destroy
  has_many :users, through: :conversation_participants
  has_many :messages, dependent: :destroy

  accepts_nested_attributes_for :conversation_participants, allow_destroy: true

  # @validations ..............................................................
  validates :public_id, presence: true, uniqueness: true
  validate :canonical_friendship_is_immutable, on: :update
  validate :canonical_participants_match_friendship, if: :friendship_id?

  # @callbacks ................................................................
  before_validation -> { self.public_id ||= SecureRandom.uuid }, on: :create

  # @scopes ...................................................................
  scope :for_users, lambda { |user_ids|
    ids = Array(user_ids).uniq

    joins(:conversation_participants)
      .where(conversation_participants: { user_id: ids })
      .group("conversations.id")
      .having("COUNT(DISTINCT conversation_participants.user_id) = ?", ids.size)
  }
  scope :for_scenario, ->(scenario_key) { where(scenario_key:) }
  scope :active_for, lambda { |user|
    joins(:conversation_participants).where(conversation_participants: { user_id: user.id, archived_at: nil })
  }
  scope :archived_for, lambda { |user|
    joins(:conversation_participants).where(conversation_participants: { user_id: user.id }).where.not(conversation_participants: { archived_at: nil })
  }
  scope :muted_for, lambda { |user|
    joins(:conversation_participants).where(conversation_participants: { user_id: user.id }).where.not(conversation_participants: { muted_at: nil })
  }
  scope :with_unread_for, lambda { |user|
    joins(:conversation_participants, :messages)
      .where(conversation_participants: { user_id: user.id })
      .merge(Message.latest)
      .where.not(messages: { user_id: user.id })
      .where("messages.id > COALESCE(conversation_participants.last_read_message_id, 0)")
      .distinct
  }

  # @additional_config ........................................................
  # @class_methods ............................................................
  def self.fast_create(user1, user2)
    find_or_create_human_between!(user1, user2)
  end

  def self.find_by_public_id!(public_id)
    find_by!(public_id:)
  end

  def self.find_or_create_human_between!(user1, user2, scenario_key: nil)
    resolve_between!(user1, user2, kind: :human, scenario_key:)
  end

  def self.find_or_create_assistant_between!(user1, user2, scenario_key: nil)
    resolve_between!(user1, user2, kind: :assistant, scenario_key:)
  end

  def self.resolve_between!(user1, user2, kind:, scenario_key: nil)
    Logic::Conversations::Resolve.call(actor: user1, friendship: user1.friendship_with(user2), kind:, scenario_key:)
  end

  # @public_instance_methods ..................................................
  def friend_for(user)
    participants = users.loaded? ? users.target : users.to_a

    participants.find { |participant| participant.id != user.id }
  end

  def title_for(user)
    friend = friend_for(user)
    friend_name = friend&.profile&.display_name.presence || friend&.email

    if human?
      friend_name
    else
      I18n.t("activerecord.attributes.conversation.assistant_with", name: friend_name)
    end
  end

  def unread_count_for(user)
    participant_for(user)&.unread_count.to_i
  end

  def participant_for(user)
    if conversation_participants.loaded?
      conversation_participants.target.find { |participant| participant.user_id == user.id }
    else
      conversation_participants.find_by(user:)
    end
  end

  def participant_for!(user)
    participant_for(user) || raise(ActiveRecord::RecordNotFound)
  end

  def latest_message
    return messages.max_by(&:created_at) if messages.loaded?

    messages.order(created_at: :desc).first
  end

  def to_param
    public_id
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def canonical_friendship_is_immutable
    return unless will_save_change_to_friendship_id?
    return if friendship_id_was.nil?

    errors.add(:friendship, :readonly)
  end

  def canonical_participants_match_friendship
    participant_ids = conversation_participants.reject(&:marked_for_destruction?).map(&:user_id)
    expected_ids = [ friendship.user_id, friendship.friend_id ]
    return if participant_ids.size == 2 && participant_ids.sort == expected_ids.sort

    errors.add(:conversation_participants, :invalid)
  end
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id            :bigint           not null, primary key
#  kind          :string           default("human"), not null, indexed, uniquely indexed => [friendship_id], uniquely indexed => [friendship_id, scenario_key]
#  scenario_key  :string           uniquely indexed => [friendship_id, kind], indexed
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  friendship_id :bigint           indexed, uniquely indexed => [kind], uniquely indexed => [kind, scenario_key]
#  public_id     :uuid             not null, uniquely indexed
#
# Indexes
#
#  index_conversations_on_friendship_id                (friendship_id)
#  index_conversations_on_kind                         (kind)
#  index_conversations_on_main_canonical_identity      (friendship_id,kind) UNIQUE WHERE ((friendship_id IS NOT NULL) AND (scenario_key IS NULL))
#  index_conversations_on_public_id                    (public_id) UNIQUE
#  index_conversations_on_scenario_canonical_identity  (friendship_id,kind,scenario_key) UNIQUE WHERE ((friendship_id IS NOT NULL) AND (scenario_key IS NOT NULL))
#  index_conversations_on_scenario_key                 (scenario_key)
#
# Foreign Keys
#
#  fk_rails_...  (friendship_id => friendships.id)
#
