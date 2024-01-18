# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  starting_price        :decimal(, )      not null
#  price                 :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum exchange_type: { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  include StartingPriceCallback
  include MoneyTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :entity_transaction

  # @validations ..............................................................
  validates :exchange_type, :number, :starting_price, :price, presence: true

  # @callbacks ................................................................
  # after_commit :handle_money_transaction

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def mt_comment = ''

  # Generates the params for the associated MoneyTransaction.
  #
  # @return [Hash]
  #
  # @see MoneyTransaction
  #
  def money_transaction_params
    transactable = entity_transaction.transactable
    category_id = transactable.user.categories.find_by(category_name: 'Exchange Return').id

    {
      mt_description: "Exchange - #{entity_transaction.transactable} #{number}/#{entity_transaction.exchanges_count}",
      date: transactable.date,
      month: transactable.month,
      year: transactable.year,
      user_id: transactable.user_id,
      money_transaction_type: model_name.name,
      user_bank_account_id: transactable.user.user_bank_accounts.ids.sample,
      category_transaction_attributes: [{ category_id: }],
      entity_transaction_attributes: []
    }
  end

  # @private_instance_methods .................................................
end
