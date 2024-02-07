# frozen_string_literal: true

# Shared functionality for models that can produce MoneyTransactions.
module ExchangeMoneyTransactable
  extend ActiveSupport::Concern

  included do
    # @includes ...............................................................
    include Backend::MathsHelper

    # @security (i.e. attr_accessible) ........................................
    # attr_accessor :money_transaction_attributes

    # @relationships ..........................................................
    belongs_to :money_transaction, optional: true
    delegate :transactable, to: :entity_transaction
    delegate :user, to: :transactable

    # @callbacks ..............................................................
    after_validation :update_entity_transaction_status, on: :update
    before_create :create_money_transaction
    before_update :update_money_transaction
    before_update :destroy_money_transaction, if: :non_monetary?
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets the `status` of the `entity_transaction` based on the existing `exchanges`.
  # In case there is only `non_monetary?` `exchanges`, then `status` is set to `finished`.
  # In case there are `monetary?` and they are all `paid`, then `status` is also set to `finished`.
  # Otherwise, `status` is set to `pending`.
  #
  # @note This is a method that is called after_validation.
  #
  # @return [void]
  #
  def update_entity_transaction_status
    return if entity_transaction.exchanges.empty?

    all_non_monetary_and_paid = entity_transaction.exchanges.all? do |exchange|
      exchange.non_monetary? || exchange.money_transaction.try(:paid)
    end

    entity_transaction.status = all_non_monetary_and_paid ? :finished : :pending
  end

  # Creates a new `money_transaction` if `exchange_type` is `monetary`.
  #
  # @note This is a method that is called before_create.
  #
  # @see {MoneyTransaction}
  # @see {#money_transaction_params}
  #
  # @return [void]
  #
  def create_money_transaction
    return if non_monetary?

    self.money_transaction = MoneyTransaction.create(money_transaction_params)
  end

  # @note This is a method that is called before_update.
  #
  # @see {#create_money_transaction}
  # @see {#money_transaction_params}
  #
  # @return [void]
  #
  def update_money_transaction
    return create_money_transaction unless money_transaction

    return if (changes.keys - %w[created_at updated_at]).empty?

    money_transaction.update(money_transaction_params)
  end

  # Sets `money_transaction_id` to nil if `exchange_type` has changed to `non_monetary`.
  # It then proceeds to destroy the associated `money_transaction`.
  #
  # @note This is a method that is called after_validation.
  #
  # @return [void]
  #
  def destroy_money_transaction
    return if changes[:exchange_type].blank?

    money_transaction_id_to_be_deleted = money_transaction_id
    self.money_transaction_id = nil
    MoneyTransaction.find(money_transaction_id_to_be_deleted).destroy
  end

  # Generates the params for the associated `money_transaction`.
  #
  # @return [Hash] The params for the associated `money_transaction`.
  #
  # @see {MoneyTransaction}
  #
  def money_transaction_params
    {
      mt_description: "Exchange - #{transactable} #{number}/#{entity_transaction.exchanges_count}",
      starting_price:, price:,
      date: transactable.date, month: transactable.month, year: transactable.year,
      user_id: user.id,
      money_transaction_type: model_name.name,
      user_bank_account_id: user.user_bank_accounts.ids.sample,
      category_transactions: FactoryBot.build_list(
        :category_transaction, 1, transactable: self, category: user.built_in_category("Exchange Return")
      )
    }
  end
end
