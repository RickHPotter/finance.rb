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
