# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  entity_name :string           not null
#  user_id     :bigint           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Entity < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  has_many :entity_transactions
  has_many :card_transactions, through: :entity_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :money_transactions, through: :entity_transactions, source: :transactable, source_type: "MoneyTransaction"

  # @validations ..............................................................
  validates :entity_name, presence: true, uniqueness: { scope: :user_id }

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
