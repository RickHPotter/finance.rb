# frozen_string_literal: true

class HealthCheckRun < ApplicationRecord
  # @extends ..................................................................
  enum :execution_state, HealthCheck::Vocabulary::EXECUTION_STATES.index_with(&:itself), prefix: true, validate: true
  enum :outcome, HealthCheck::Vocabulary::OUTCOMES.index_with(&:itself), prefix: true, validate: { allow_nil: true }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :context
  belongs_to :connected_user, class_name: "User", optional: true

  # @validations ..............................................................
  validates :check_key, inclusion: { in: ->(_) { HealthCheck::Registry.keys } }
  validates :generation_token, :queued_at, presence: true
  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :error_code, length: { maximum: 100 }, format: { with: /\A[a-z0-9_]+\z/ }, allow_nil: true
  validates :check_key,
            uniqueness: {
              scope: %i[user_id context_id],
              conditions: -> { where(connected_user_id: nil) }
            },
            if: -> { connected_user_id.nil? }
  validates :check_key,
            uniqueness: { scope: %i[user_id context_id connected_user_id] },
            if: -> { connected_user_id.present? }
  validate :counts_follow_contract
  validate :context_belongs_to_user
  validate :outcome_matches_execution_state
  validate :error_matches_execution_state
  validate :timestamps_are_ordered

  # @callbacks ................................................................
  before_validation :assign_execution_defaults
  before_validation :normalize_counts
  before_validation :normalize_error_code

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  private

  def assign_execution_defaults
    self.generation_token ||= SecureRandom.uuid
    self.queued_at ||= started_at || Time.current
  end

  def normalize_counts
    return unless counts.respond_to?(:to_h)

    self.counts = HealthCheck::Vocabulary::COUNT_KEYS.index_with(0).merge(counts.to_h.stringify_keys)
  end

  def normalize_error_code
    self.error_code = error_code.to_s.presence
  end

  def counts_follow_contract
    unless counts.is_a?(Hash)
      errors.add(:counts, :invalid)
      return
    end

    errors.add(:counts, :invalid) if counts.keys.difference(HealthCheck::Vocabulary::COUNT_KEYS).any?
    errors.add(:counts, :invalid) unless counts.values.all? { |value| value.is_a?(Integer) && value >= 0 }
    errors.add(:counts, :too_long, count: 4.kilobytes) if counts.to_json.bytesize > 4.kilobytes
  end

  def context_belongs_to_user
    return if context.blank? || user.blank? || context.user_id == user.id

    errors.add(:context, :invalid)
  end

  def outcome_matches_execution_state
    return if execution_state_completed? == outcome.present?

    errors.add(:outcome, :invalid)
  end

  def error_matches_execution_state
    return if execution_state_unavailable? == error_code.present?

    errors.add(:error_code, :invalid)
  end

  def timestamps_are_ordered
    errors.add(:started_at, :invalid) if queued_at.present? && started_at.present? && started_at < queued_at
    errors.add(:finished_at, :invalid) if started_at.present? && finished_at.present? && finished_at < started_at
  end
end

# == Schema Information
#
# Table name: health_check_runs
# Database name: primary
#
#  id                :bigint           not null, primary key
#  check_key         :string           not null, uniquely indexed => [user_id, context_id, connected_user_id], uniquely indexed => [user_id, context_id]
#  counts            :jsonb            not null
#  duration_ms       :bigint
#  error_code        :string(100)
#  execution_state   :string           default("queued"), not null, indexed => [updated_at]
#  finished_at       :datetime
#  generation_token  :uuid             not null
#  outcome           :string
#  queued_at         :datetime         not null
#  started_at        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null, indexed => [execution_state]
#  connected_user_id :bigint           uniquely indexed => [check_key, user_id, context_id], indexed
#  context_id        :bigint           not null, uniquely indexed => [check_key, user_id, connected_user_id], uniquely indexed => [check_key, user_id], indexed
#  user_id           :bigint           not null, uniquely indexed => [check_key, context_id, connected_user_id], uniquely indexed => [check_key, context_id], indexed
#
# Indexes
#
#  idx_health_check_runs_connected_scope                      (check_key,user_id,context_id,connected_user_id) UNIQUE WHERE (connected_user_id IS NOT NULL)
#  idx_health_check_runs_unfiltered_scope                     (check_key,user_id,context_id) UNIQUE WHERE (connected_user_id IS NULL)
#  index_health_check_runs_on_connected_user_id               (connected_user_id)
#  index_health_check_runs_on_context_id                      (context_id)
#  index_health_check_runs_on_execution_state_and_updated_at  (execution_state,updated_at)
#  index_health_check_runs_on_user_id                         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (connected_user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
