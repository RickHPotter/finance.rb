# frozen_string_literal: true

class EntityTransaction < ApplicationRecord
  # @extends ..................................................................
  enum :status, { pending: 0, finished: 1 }

  # @includes .................................................................
  include HasExchanges

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :entity, touch: true
  belongs_to :transactable, polymorphic: true

  # @validations ..............................................................
  validates :status, :price, presence: true
  validates :is_payer, inclusion: { in: [ true, false ] }
  validates :entity_id, uniqueness: { scope: %i[transactable_type transactable_id] }

  # @callbacks ................................................................
  before_validation :set_status, on: :create

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets `status` based on `is_payer` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_status
    self.status ||= is_payer ? :pending : :finished
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: entity_transactions
#
#  id                   :bigint           not null, primary key
#  exchanges_count      :integer          default(0), not null
#  is_payer             :boolean          default(FALSE), not null
#  price                :integer          default(0), not null
#  price_to_be_returned :integer          default(0), not null
#  status               :integer          default("pending"), not null
#  transactable_type    :string           not null, indexed => [entity_id, transactable_id], indexed => [transactable_id]
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  entity_id            :bigint           not null, indexed => [transactable_type, transactable_id], indexed
#  transactable_id      :bigint           not null, indexed => [entity_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_entity_transactions_on_composite_key  (entity_id,transactable_type,transactable_id) UNIQUE
#  index_entity_transactions_on_entity_id      (entity_id)
#  index_entity_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (entity_id => entities.id)
#
