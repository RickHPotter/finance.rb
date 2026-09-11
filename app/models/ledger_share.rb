# frozen_string_literal: true

class LedgerShare < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_readonly :public_id, :token_digest, :entity_id, :context_id

  # @relationships ............................................................
  belongs_to :entity
  belongs_to :context

  # @validations ..............................................................
  validates :public_id, :token_digest, presence: true
  validates :token_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :access_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :context_owner_matches_entity
  validate :expires_in_the_future, if: :will_save_change_to_expires_at?

  # @callbacks ................................................................
  before_validation :assign_public_id, on: :create

  # @scopes ...................................................................
  scope :available_at, ->(time = Time.current) { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", time) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  def self.digest_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # @public_instance_methods ..................................................
  def available_at?(time = Time.current)
    revoked_at.nil? && (expires_at.nil? || expires_at > time)
  end

  def expired?(time = Time.current)
    expires_at.present? && expires_at <= time
  end

  def revoked?
    revoked_at.present?
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def assign_public_id
    self.public_id ||= SecureRandom.uuid
  end

  def context_owner_matches_entity
    return if entity.blank? || context.blank? || entity.user_id == context.user_id

    errors.add(:context, :owner_mismatch)
  end

  def expires_in_the_future
    return if expires_at.blank? || expires_at.future?

    errors.add(:expires_at, :must_be_future)
  end
end

# == Schema Information
#
# Table name: ledger_shares
# Database name: primary
#
#  id               :bigint           not null, primary key
#  access_count     :bigint           default(0), not null
#  expires_at       :datetime
#  last_accessed_at :datetime
#  revoked_at       :datetime
#  token_digest     :string           not null, uniquely indexed
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  context_id       :bigint           not null, indexed => [entity_id], indexed
#  entity_id        :bigint           not null, indexed => [context_id], indexed
#  public_id        :uuid             not null, uniquely indexed
#
# Indexes
#
#  index_active_ledger_shares_on_scope  (entity_id,context_id) WHERE (revoked_at IS NULL)
#  index_ledger_shares_on_context_id    (context_id)
#  index_ledger_shares_on_entity_id     (entity_id)
#  index_ledger_shares_on_public_id     (public_id) UNIQUE
#  index_ledger_shares_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (entity_id => entities.id)
#
