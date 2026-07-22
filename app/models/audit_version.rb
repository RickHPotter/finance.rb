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

# == Schema Information
#
# Table name: audit_versions
# Database name: primary
#
#  id              :bigint           not null, primary key, indexed => [operation_id]
#  event           :string           not null, indexed => [created_at]
#  item_subtype    :string
#  item_type       :string           not null, indexed => [item_id, created_at]
#  metadata        :jsonb            not null
#  mutation_source :string           not null, indexed => [created_at]
#  object          :jsonb
#  object_changes  :jsonb
#  whodunnit       :string
# rubocop:disable Layout/LineLength
#  created_at      :datetime         not null, indexed => [context_id], indexed => [event], indexed => [item_type, item_id], indexed => [mutation_source], indexed => [owner_id]
# rubocop:enable Layout/LineLength
#  context_id      :bigint           indexed => [created_at]
#  item_id         :bigint           not null, indexed => [item_type, created_at]
#  operation_id    :uuid             not null, indexed => [id]
#  owner_id        :bigint           not null, indexed => [created_at]
#
# Indexes
#
#  index_audit_versions_on_context_id_and_created_at             (context_id,created_at)
#  index_audit_versions_on_event_and_created_at                  (event,created_at)
#  index_audit_versions_on_item_type_and_item_id_and_created_at  (item_type,item_id,created_at)
#  index_audit_versions_on_mutation_source_and_created_at        (mutation_source,created_at)
#  index_audit_versions_on_operation_id_and_id                   (operation_id,id)
#  index_audit_versions_on_owner_id_and_created_at               (owner_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (operation_id => audit_operations.id) ON DELETE => restrict
#
