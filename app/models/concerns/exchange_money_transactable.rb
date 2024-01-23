# frozen_string_literal: true

# Shared functionality for models that can produce MoneyTransactions.
module ExchangeMoneyTransactable
  include Backend::MathsHelper
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    # attr_accessor :money_transaction_attributes

    # @relationships ..........................................................
    belongs_to :money_transaction, optional: true

    # @callbacks ..............................................................
    after_validation :dettach_money_transaction
    after_validation :update_entity_transaction_status
    before_create :create_money_transaction
    before_update :update_money_transaction
    before_update :handle_orphan_exchanges
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def dettach_money_transaction
    return if changes[:exchange_type].blank?

    self.money_transaction_id = nil
  end

  def update_entity_transaction_status
    entity_transaction.status =
      if entity_transaction.exchanges.map(&:exchange_type).uniq == ['non_monetary']
        :finished
      else
        :pending
      end
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

  def create_money_transaction
    return if non_monetary?

    self.money_transaction = MoneyTransaction.create(money_transaction_params)
  end

  def update_money_transaction
    return create_money_transaction unless money_transaction

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
end
