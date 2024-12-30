# frozen_string_literal: true

# Shared functionality for models that can produce CashTransactions.
module ExchangeMoneyTransactable
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    belongs_to :cash_transaction, optional: true
    delegate :transactable, to: :entity_transaction
    delegate :user, to: :transactable

    # @callbacks ..............................................................
    after_validation :update_entity_transaction_status, on: :update
    before_create :create_cash_transaction, if: :monetary?
    before_update :update_cash_transaction
    before_update :destroy_cash_transaction, if: :non_monetary?
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
  # @return [void].
  #
  def update_entity_transaction_status
    return if entity_transaction.exchanges.empty?

    all_non_monetary_and_paid = [ *entity_transaction.exchanges, self ].all? do |exchange|
      exchange.non_monetary? || exchange.cash_transaction.try(:paid)
    end

    entity_transaction.status = all_non_monetary_and_paid ? :finished : :pending
  end

  # Creates a new `cash_transaction` if `exchange_type` is `monetary`.
  #
  # @note This is a method that is called before_create.
  #
  # @see {CashTransaction}.
  # @see {#cash_transaction_params}.
  #
  # @return [void].
  #
  def create_cash_transaction
    self.cash_transaction = CashTransaction.create(cash_transaction_params)
  end

  # @note This is a method that is called before_update.
  #
  # @see {#create_cash_transaction}.
  # @see {#cash_transaction_params}.
  #
  # @return [void].
  #
  def update_cash_transaction
    return create_cash_transaction unless cash_transaction

    return if (changes.keys - %w[created_at updated_at]).empty?

    cash_transaction.update(cash_transaction_params)
  end

  # Sets `cash_transaction_id` to nil if `exchange_type` has changed to `non_monetary`.
  # It then proceeds to destroy the associated `cash_transaction`.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void].
  #
  def destroy_cash_transaction
    return if changes[:exchange_type].blank?

    cash_transaction_id_to_be_destroyed = cash_transaction_id
    self.cash_transaction_id = nil
    CashTransaction.find(cash_transaction_id_to_be_destroyed).destroy
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `cash_transaction`.
  #
  def cash_transaction_params
    {
      description: "EXCHANGE - #{transactable} #{number}/#{entity_transaction.exchanges_count}",
      starting_price:, price:,
      date: transactable.date, month: transactable.month, year: transactable.year,
      user_id: user.id,
      cash_transaction_type: model_name.name,
      user_bank_account_id: user.user_bank_accounts.ids.sample,
      category_transactions: FactoryBot.build_list(
        :category_transaction, 1, transactable: self, category: user.built_in_category("EXCHANGE RETURN")
      )
    }
  end
end
