# frozen_string_literal: true

class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum :exchange_type, { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include ExchangeCashTransactable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :locked

  # @relationships ............................................................
  belongs_to :entity_transaction, counter_cache: true

  # @validations ..............................................................
  validates :exchange_type, :number, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def projection_locked?
    cash_transaction&.paid_history? || false
  end

  def mirrored_cash_installment
    return cash_transaction.cash_installments&.order(:number, :date)&.first if cash_transaction && card_bound?

    cash_transaction&.cash_installments&.find_by(number:)
  end

  def mirrored_paid?
    return cash_transaction&.paid? || false if card_bound?

    mirrored_cash_installment&.paid? || false
  end

  def mirrored_cash_installments_match?
    return true if non_monetary? || cash_transaction.blank?
    return true if card_bound?

    exchange_rows = sibling_exchanges_for_cash_transaction.map { |record| [ record.number, record.date.to_date, record.price ] }.sort
    installment_rows = cash_transaction.cash_installments.map { |record| [ record.number, record.date.to_date, record.price ] }.sort

    exchange_rows == installment_rows
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def sibling_exchanges_for_cash_transaction
    Exchange.where(cash_transaction_id:)
  end
end

# == Schema Information
#
# Table name: exchanges
# Database name: primary
#
#  id                    :bigint           not null, primary key
#  bound_type            :string           default("standalone"), not null
#  date                  :datetime         not null
#  exchange_type         :integer          default("non_monetary"), not null
#  exchanges_count       :integer          default(0), not null
#  month                 :integer          not null
#  number                :integer          default(1), not null
#  price                 :integer          not null
#  starting_price        :integer          not null
#  year                  :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cash_transaction_id   :bigint           indexed
#  entity_transaction_id :bigint           not null, indexed
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
