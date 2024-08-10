# frozen_string_literal: true

# == Schema Information
#
# Table name: entity_transactions
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  exchanges_count   :integer          default(0), not null
#  entity_id         :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
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
