# frozen_string_literal: true

class AuditVersion < ApplicationRecord
  # @extends ..................................................................
  EVENTS = %w[create update destroy].freeze
  MUTATION_SOURCES = (AuditOperation::ROOT_SOURCES + %w[shared_sync projection_sync reference_sync piggy_bank_sync balance_recalculation]).freeze

  enum :event, EVENTS.index_with(&:itself), prefix: true, validate: true
  enum :mutation_source, MUTATION_SOURCES.index_with(&:itself), prefix: true, validate: true

  # @includes .................................................................
  include PaperTrail::VersionConcern

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :operation, class_name: "AuditOperation", foreign_key: :operation_id, inverse_of: :audit_versions

  # @validations ..............................................................
  validates :item_type, :item_id, :owner_id, :event, :mutation_source, presence: true
  validate :json_payloads_within_size_limits

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def readonly?
    persisted?
  end

  def reify(options = {})
    return super if item_subtype.blank? || item_subtype == item_type

    reification_version = dup
    reification_version[:item_type] = item_subtype
    reified_item = PaperTrail::Reifier.reify(reification_version, options)
    reified_item.public_send(:"#{reified_item.class.version_association_name}=", self)
    reified_item
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  private

  def json_payloads_within_size_limits
    errors.add(:metadata, :too_long, count: 16.kilobytes) if metadata.to_json.bytesize > 16.kilobytes
    errors.add(:object, :too_long, count: 256.kilobytes) if object.to_json.bytesize > 256.kilobytes
    errors.add(:object_changes, :too_long, count: 256.kilobytes) if object_changes.to_json.bytesize > 256.kilobytes
  end
end
