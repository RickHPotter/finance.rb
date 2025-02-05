# frozen_string_literal: true

class Entity < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  has_many :entity_transactions, dependent: :destroy
  has_many :card_transactions, through: :entity_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :entity_transactions, source: :transactable, source_type: "CashTransaction"

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

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  entity_name :string           not null, indexed, indexed => [user_id]
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null, indexed, indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_entity_name       (entity_name) UNIQUE
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
