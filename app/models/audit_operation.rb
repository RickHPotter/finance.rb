# frozen_string_literal: true

class AuditOperation < ApplicationRecord
  # @extends ..................................................................
  ROOT_SOURCES = %w[web api actionable_message admin_repair import background_job rollback console unknown].freeze
  RESULTS = %w[committed rejected failed].freeze

  enum :source, ROOT_SOURCES.index_with(&:itself), prefix: true, validate: true
  enum :result, RESULTS.index_with(&:itself), prefix: true, validate: true

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  has_many :audit_versions, foreign_key: :operation_id, inverse_of: :operation

  # @validations ..............................................................
  validates :source, :result, presence: true
  validate :metadata_within_size_limit

  # @callbacks ................................................................
  before_validation :assign_id, on: :create

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

  def assign_id
    self.id ||= SecureRandom.uuid
  end

  def metadata_within_size_limit
    return if metadata.to_json.bytesize <= 16.kilobytes

    errors.add(:metadata, :too_long, count: 16.kilobytes)
  end
end

# == Schema Information
#
# Table name: audit_operations
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  metadata                 :jsonb            not null
#  result                   :string           not null
#  source                   :string           not null, indexed => [created_at]
#  created_at               :datetime         not null, indexed => [actor_id], indexed => [context_id], indexed => [source]
#  actor_id                 :bigint           indexed => [created_at]
#  context_id               :bigint           indexed => [created_at]
#  parent_operation_id      :uuid             indexed
#  request_id               :string           indexed
#  rollback_of_operation_id :uuid             indexed
#  selected_version_id      :bigint
#
# Indexes
#
#  index_audit_operations_on_actor_id_and_created_at    (actor_id,created_at)
#  index_audit_operations_on_context_id_and_created_at  (context_id,created_at)
#  index_audit_operations_on_parent_operation_id        (parent_operation_id)
#  index_audit_operations_on_request_id                 (request_id) WHERE (request_id IS NOT NULL)
# rubocop:disable Layout/LineLength
#  index_audit_operations_on_rollback_idempotency       (rollback_of_operation_id, actor_id, ((metadata ->> 'preview_digest'::text))) UNIQUE WHERE (((source)::text = 'rollback'::text) AND ((result)::text = 'committed'::text) AND (rollback_of_operation_id IS NOT NULL) AND (actor_id IS NOT NULL) AND (metadata ? 'preview_digest'::text))
# rubocop:enable Layout/LineLength
#  index_audit_operations_on_rollback_of_operation_id   (rollback_of_operation_id)
#  index_audit_operations_on_source_and_created_at      (source,created_at)
#
