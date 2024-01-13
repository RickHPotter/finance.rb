# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  amount_to_be_returned :decimal(, )      not null
#  amount_returned       :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum exchange_type: { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :entity_transaction
  belongs_to :money_transaction, optional: true

  # @validations ..............................................................
  validates :exchange_type, :amount_to_be_returned, :amount_returned,
            :entity_transaction, presence: true

  # @callbacks ................................................................
  # after_commit :handle_money_transaction

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def handle_money_transaction
    return create_money_transaction if created?

    if changes[:exchange_type].present?
      create_money_transaction if monetary?
      delete_money_transaction if non_monetary?
    end

    return unless changes.keys.intersect? %w[amount_to_be_returned amount_returned]

    update_money_transaction
  end

  # TODO: docs
  def create_money_transaction
    self.money_transaction = MoneyTransaction.create(money_transaction_params)
  end

  # Generates the params for the associated MoneyTransaction.
  #
  # @return [Hash]
  #
  # @see MoneyTransaction
  #

  def money_transaction_params
    mt_description = "Exchange - #{entity_transaction.transactable}"
    mt_comment = ''
    # month = entity_transaction.transactable.month
    params = {
      mt_description:, mt_comment:, month:, year:, user_id:,
      date: transactable_date, money_transaction_type: model_name.name
    }
    params[:user_card_id] = user_card_id if respond_to? :user_card_id
    params[:user_bank_account_id] = user_bank_account_id if respond_to? :user_bank_account_id

    params
  end

  def delete_money_transaction
    money_transaction.destroy
  end

  def update_money_transaction
    money_transaction.update(price: amount_to_be_returned)
  end

  # @private_instance_methods .................................................
end
