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

  # TODO: docs
  def handle_money_transaction
    # return create_money_transaction if created?
    #
    # if changes[:exchange_type].present?
    #   create_money_transaction if monetary?
    #   delete_money_transaction if non_monetary?
    # end
    #
    # return unless changes.keys.intersect? %w[amount_to_be_returned amount_returned]
    #
    # update_money_transaction
  end

  # TODO: docs
  def create_money_transaction
    # self.money_transaction = MoneyTransaction.create(money_transaction_params)
  end

  def mt_comment = ''

  # Generates the params for the associated MoneyTransaction.
  #
  # @return [Hash]
  #
  # @see MoneyTransaction
  #
  def money_transaction_params
    transactable = entity_transaction.transactable

    {
      mt_description: "Exchange - #{entity_transaction.transactable} #{number}/#{entity_transaction.exchanges.count}",
      date: transactable.date,
      month: transactable.month,
      year: transactable.year,
      user_id: transactable.user_id,
      money_transaction_type: model_name.name,
      user_bank_account_id: transactable.user.user_bank_accounts.ids.sample
    }
  end

  # @private_instance_methods .................................................
end
