# frozen_string_literal: true

class Card < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :bank
  has_many :user_cards

  # @validations ..............................................................
  validates :card_name, presence: true, uniqueness: true

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
# Table name: cards
#
#  id         :bigint           not null, primary key
#  card_name  :string           not null, uniquely indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bank_id    :bigint           not null, indexed
#
# Indexes
#
#  index_cards_on_bank_id    (bank_id)
#  index_cards_on_card_name  (card_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id)
#
