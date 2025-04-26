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
  def update_card_transactions_count_and_total
    update_columns(card_transactions_count: card_transactions.count, card_transactions_total: card_transactions.sum(:price))
  end

  def update_cash_transactions_count_and_total
    update_columns(cash_transactions_count: cash_transactions.count, cash_transactions_total: cash_transactions.sum(:price))
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: entities
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  avatar_name             :string           default("people/0.png"), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  entity_name             :string           not null, indexed => [user_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed, indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
