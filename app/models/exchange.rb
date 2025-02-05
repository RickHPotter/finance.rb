# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  price                 :integer          not null
#  starting_price        :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cash_transaction_id   :bigint
#  entity_transaction_id :bigint           not null
#
# Indexes
#
#  index_exchanges_on_cash_transaction_id    (cash_transaction_id)
#  index_exchanges_on_entity_transaction_id  (entity_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (entity_transaction_id => entity_transactions.id)
#
class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum :exchange_type, { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  include HasStartingPrice
  include ExchangeCashTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :entity_transaction, counter_cache: true

  # @validations ..............................................................
  validates :exchange_type, :number, :starting_price, :price, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
