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

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :entity_transaction

  belongs_to :money_transaction, optional: true

  # @validations ..............................................................
  validates :exchange_type, :number, :starting_price, :price, presence: true

  # @callbacks ................................................................
  before_save :handle_monetary
  before_save :handle_orphan_exchanges
  after_commit :handle_money_transaction, on: %i[create update]

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def handle_monetary
    return if changes[:exchange_type].blank?
    return if monetary?

    self.money_transaction_id = nil
  end

  def handle_orphan_exchanges
    return if changes[:exchange_type].blank?
    return if monetary?

    MoneyTransaction
      .by_user(transactable.user)
      .where(money_transaction_type: 'Exchange')
      .select { |mt| mt.exchanges.empty? }
      .map(&:destroy)
  end

  def handle_money_transaction
    return if non_monetary?
    return update_money_transaction if money_transaction.present?

    create_money_transaction
  end

  def create_money_transaction
    self.money_transaction = MoneyTransaction.create(money_transaction_params)
  end

  def update_money_transaction
    return if (changes.keys - %w[created_at updated_at]).empty?

    money_transaction.update(money_transaction_params)
  end

  def transactable = entity_transaction.transactable

  def money_transaction_params
    {
      mt_description:, starting_price:, price:,
      date: transactable.date, month: transactable.month, year: transactable.year,
      user_id: transactable.user_id,
      money_transaction_type: model_name.name,
      user_bank_account_id: transactable.user.user_bank_accounts.ids.sample,
      category_transaction_attributes: [{ category_id: exchange_return_category_id }],
      entity_transaction_attributes: []
    }
  end

  def mt_description
    "Exchange - #{transactable} #{number}/#{entity_transaction.exchanges_count}"
  end

  def exchange_return_category_id
    transactable.user.categories.find_by(category_name: 'Exchange Return').id
  end

  # @private_instance_methods .................................................
end
