# frozen_string_literal: true

class Friendship < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include FinancialAuditable

  audits_financial_changes

  # @security (i.e. attr_accessible) ..........................................
  enum :state, { pending: "pending", accepted: "accepted", rejected: "rejected", blocked: "blocked", removed: "removed" }, suffix: true

  store_accessor :policies, :auto_accept_actionable_messages, :boolean

  # @relationships ............................................................
  belongs_to :user
  belongs_to :friend, class_name: "User"
  has_many :entities, dependent: :nullify

  # @validations ..............................................................
  validates :public_id, :state, presence: true
  validate :canonical_uniqueness, on: :create

  # @callbacks ................................................................
  before_validation -> { self.public_id ||= SecureRandom.uuid }, on: :create

  private

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
