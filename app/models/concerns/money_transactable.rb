# frozen_string_literal: true

# Shared functionality for models that are accumulated to a single MoneyTransaction.
module MoneyTransactable
  extend ActiveSupport::Concern

  included do
    belongs_to :money_transaction, optional: true

    before_save :attach_money_transaction
    after_commit :update_money_transaction, on: %i[create update]
    after_commit :update_or_destroy_money_transaction, on: :destroy
  end

  # @protected_instance_methods ...............................................

  protected

  # Attachs a MoneyTransaction to the self model (by finding one or creating it).
  #
  # This method is a `before_save` callback that associates a MoneyTransaction with the self model.
  # It creates or finds a MoneyTransaction based on certain attributes and sets it to the
  # `money_transaction` relation of the self model.
  #
  # @return [void]
  #
  # @see MoneyTransaction
  #
  def attach_money_transaction
    self.money_transaction = MoneyTransaction.create_with(price:).find_or_create_by(money_transaction_params)
  end

  # Generates the params for the associated MoneyTransaction.
  #
  # @return [Hash]
  #
  # @see MoneyTransaction
  #
  def money_transaction_params
    params = {
      mt_description:, month:, year:, user_id:,
      date: money_transaction_date, money_transaction_type: model_name.name
    }
    params[:user_card_id] = user_card_id if respond_to? :user_card_id
    params[:user_bank_account_id] = user_bank_account_id if respond_to? :user_bank_account_id

    params
  end

  # Updates the associated MoneyTransaction with self model details.
  #
  # This method is an `after_commit` callback triggered on `create` and `update` actions.
  # It updates the associated MoneyTransaction with the sum of self instances prices and
  # a comment describing the days of associated self instances.
  #
  # @return [void]
  #
  # @see MoneyTransaction
  #
  def update_money_transaction
    transactable = money_transaction.public_send(model_name.plural)
    price = transactable.sum(:price).round(2)

    money_transaction.update(price:, mt_comment:)
  end

  # Updates or destroys the associated MoneyTransaction based on self instances count.
  #
  # This method is an `after_commit` callback triggered on `destroy` actions.
  # It checks the count of associated self instances, and if zero, destroys the associated MoneyTransaction.
  # Otherwise, it updates the MoneyTransaction using {#update_money_transaction}.
  #
  # @return [void]
  #
  # @see update_money_transaction
  #
  def update_or_destroy_money_transaction
    transactable = money_transaction.public_send(model_name.plural)
    if transactable.count.zero?
      money_transaction.destroy
    else
      update_money_transaction
    end
  end
end
