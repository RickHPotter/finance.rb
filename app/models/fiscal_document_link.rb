# frozen_string_literal: true

class FiscalDocumentLink < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :context
  belongs_to :transactable, polymorphic: true

  # @validations ..............................................................
  validates :access_key, presence: true
  validate :valid_fiscal_access_key
  validate :consistent_ownership

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  private

  def valid_fiscal_access_key
    errors.add(:access_key, :invalid) unless FiscalReceipts::AccessKey.new(access_key).valid?
  end

  def consistent_ownership
    return if transactable.present? && transactable.user_id == user_id && transactable.context_id == context_id && context&.user_id == user_id

    errors.add(:base, :invalid)
  end
end

# == Schema Information
#
# Table name: fiscal_document_links
# Database name: primary
#
#  id                :bigint           not null, primary key
#  access_key        :string(44)       not null, indexed => [user_id, context_id]
#  transactable_type :string           not null, uniquely indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  context_id        :bigint           not null, indexed, indexed => [user_id, access_key]
#  transactable_id   :bigint           not null, uniquely indexed => [transactable_type]
#  user_id           :bigint           not null, indexed => [context_id, access_key], indexed
#
# Indexes
#
#  index_fiscal_document_links_on_context_id     (context_id)
#  index_fiscal_document_links_on_scope_and_key  (user_id,context_id,access_key)
#  index_fiscal_document_links_on_transactable   (transactable_type,transactable_id) UNIQUE
#  index_fiscal_document_links_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
