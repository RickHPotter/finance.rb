# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  amount_to_be_returned :decimal(, )      not null
#  amount_returned       :decimal(, )      not null
#  transaction_entity_id :bigint           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum exchange_type: { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :transaction_entity
  belongs_to :money_transaction, optional: true

  # @validations ..............................................................
  validates :exchange_type, :amount_to_be_returned, :amount_returned,
            :transaction_entity, presence: true

  # @callbacks ................................................................
  after_commit :handle_money_transaction

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def handle_money_transaction
    if changes[:exchange_type].present?
      create_money_transaction if monetary?
      delete_money_transaction if non_monetary?
    end

    return unless changes.keys.intersect? %w[amount_to_be_returned amount_returned]

    update_money_transaction
  end

  def create_money_transaction
    self.money_transaction = MoneyTransaction
                             .create_with(price:)
                             .find_or_create_by(money_transaction_params)

    MoneyTransaction.create(
      exchange: self,
      price: amount_to_be_returned,
      mt_comment: "Exchange for #{transaction_entity.name}"
    )
  end

  # Generates the params for the associated MoneyTransaction.
  #
  # @return [Hash]
  #
  # @see MoneyTransaction
  #
  def money_transaction_params
    mt_description = "Exchange - #{transaction_entity.transactable}"
    # month = transaction_entity.month
    params = {
      mt_description:, month:, year:, user_id:, category_id:,
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
