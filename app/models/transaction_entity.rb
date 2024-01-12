# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_entities
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  entity_id         :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class TransactionEntity < ApplicationRecord
  # @extends ..................................................................
  enum status: { pending: 0, finished: 1 }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :transactable, polymorphic: true
  belongs_to :entity

  has_many :exchanges

  # @validations ..............................................................
  validates :status, :price, :transactable_type, :transactable_id, :entity_id, presence: true
  validates :is_payer, inclusion: { in: [true, false] }

  # @callbacks ................................................................
  before_validation :set_amounts, unless: :is_payer

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets amounts and status based on :is_payer in case it was not previously set.
  #
  # @note This is a callback that is called before_validation.
  #
  # @return [void]
  #
  def set_amounts
    self.status = :finished
  end

  # @private_instance_methods .................................................
end
