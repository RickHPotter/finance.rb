# frozen_string_literal: true

class Friendship < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include FinancialAuditable

  BOOLEAN_CASTER = ActiveModel::Type::Boolean.new

  audits_financial_changes skip: [ :policies ]

  # @security (i.e. attr_accessible) ..........................................
  enum :state, { pending: "pending", accepted: "accepted", rejected: "rejected", blocked: "blocked", removed: "removed" }, suffix: true

  # store_accessor on JSONB reads the raw hash directly, bypassing the
  # attribute type system, so :boolean type-hints are silently ignored.
  # These explicit reader/writer methods normalise to proper booleans.
  def auto_accept_actionable_messages
    BOOLEAN_CASTER.cast(policies&.dig("auto_accept_actionable_messages"))
  end

  def auto_accept_actionable_messages=(value)
    self.policies = (policies || {}).merge("auto_accept_actionable_messages" => BOOLEAN_CASTER.cast(value))
  end

  # @relationships ............................................................
  belongs_to :user
  belongs_to :friend, class_name: "User"
  has_many :conversations, dependent: :restrict_with_error
  has_many :entities, dependent: :nullify

  # @validations ..............................................................
  validates :public_id, :state, presence: true
  validate :canonical_uniqueness, on: :create

  # @callbacks ................................................................
  before_validation -> { self.public_id ||= SecureRandom.uuid }, on: :create
  after_update :revoke_conversation_access, if: :accepted_friendship_revoked?
  after_update_commit :broadcast_conversation_revocation, if: :accepted_friendship_revoked?

  private

  def accepted_friendship_revoked?
    saved_change_to_state? && state_before_last_save == "accepted" && !accepted_state?
  end

  def revoke_conversation_access
    Logic::Conversations::RevokeAccess.call(friendship: self)
  end

  def broadcast_conversation_revocation
    Logic::Conversations::RevokeAccess.new(friendship: self).broadcast
  end

  def canonical_uniqueness
    return unless Friendship.where(user_id: [ user_id, friend_id ], friend_id: [ user_id, friend_id ]).exists?

    errors.add(:base, "Friendship already exists")
  end
end

# == Schema Information
#
# Table name: friendships
# Database name: primary
#
#  id         :bigint           not null, primary key
#  policies   :jsonb            not null
#  state      :string           default("pending"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  friend_id  :bigint           not null, indexed
#  public_id  :string           not null, uniquely indexed
#  user_id    :bigint           not null, indexed
#
# Indexes
#
#  index_friendships_on_friend_id                  (friend_id)
#  index_friendships_on_public_id                  (public_id) UNIQUE
#  index_friendships_on_user_and_friend_canonical  (LEAST(user_id, friend_id), GREATEST(user_id, friend_id)) UNIQUE
#  index_friendships_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (friend_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
