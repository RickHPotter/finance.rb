# frozen_string_literal: true

class Exchange < ApplicationRecord
  # @extends ..................................................................
  enum :exchange_type, { non_monetary: 0, monetary: 1 }

  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include ExchangeCashTransactable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :locked, :replay_paid_state

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

  def effective_paid_state
    return ActiveModel::Type::Boolean.new.cast(replay_paid_state) unless replay_paid_state.nil?

    mirrored_paid? || shared_exchange_mirrored_paid?
  end

  # The exchange form submits datetime-local values with minute precision. Keep
  # an existing timestamp intact when that value denotes the same minute, so a
  # rendered paid exchange does not become dirty merely by submitting the form.
  def date=(value)
    super unless preserve_existing_timestamp_for_minute_value?(value)
  end

  def mirrored_cash_installments_match?
    return true if non_monetary? || cash_transaction.blank?
    return true if card_bound?

    exchange_rows = sibling_exchanges_for_cash_transaction.map { |record| [ record.number, record.date.to_date, record.price ] }.sort
    installment_rows = cash_transaction.cash_installments.map { |record| [ record.number, record.date.to_date, record.price ] }.sort

    exchange_rows == installment_rows
  end

  def shared_exchange_mirrored_paid?
    return false if entity_transaction.blank? # transactable is delegated to entity_transaction
    return false if transactable.blank?

    counterpart_transactable = transactable.reference_transactable
    return false if counterpart_transactable.blank?

    # FIXME: this is the path for loan EXCHANGE, but not sure for reimbursement, any input?
    counterpart_transactable = counterpart_transactable.reference_transactable if counterpart_transactable.exchange_return?

    counterpart_entity_transaction = counterpart_transactable.entity_transactions.joins(:entity).find_by(entity: { entity_user_id: user.id })
    return false if counterpart_entity_transaction.blank?

    counterpart_exchange = counterpart_entity_transaction.exchanges.find_by(number:)
    return false if counterpart_exchange.blank?

    counterpart_exchange.mirrored_paid?
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def preserve_existing_timestamp_for_minute_value?(value)
    persisted? &&
      value.is_a?(String) &&
      value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/) &&
      date&.strftime("%Y-%m-%dT%H:%M") == value
  end

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
