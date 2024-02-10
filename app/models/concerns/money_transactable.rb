# frozen_string_literal: true

# Shared functionality for models that are accumulated to a single MoneyTransaction.
module MoneyTransactable
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    belongs_to :money_transaction, optional: true

    # @callbacks ..............................................................
    before_save :attach_money_transaction
    after_commit :update_money_transaction, on: %i[create update]
    after_commit :update_or_destroy_money_transaction, on: :destroy
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Attachs a `money_transaction` to `self.money_transaction` (by finding one or creating it).
  #
  # This method creates or finds a `money_transaction` based on certain attributes and links it
  # to this model.
  #
  # @note This is a method that is called before_save.
  #
  # @see {MoneyTransaction}
  #
  # @return [void]
  #
  def attach_money_transaction
    self.money_transaction = MoneyTransaction.create_with(price:).find_or_create_by(money_transaction_params)
  end

  # Generates the params for the associated `money_transaction`.
  #
  # @see {MoneyTransaction}
  #
  # @return [Hash] The params for the associated `money_transaction`.
  #
  def money_transaction_params
    params = {
      mt_description:,
      month:, year:,
      date: money_transaction_date,
      user_id:,
      money_transaction_type: model_name.name
    }
    params[:user_card_id] = user_card_id if respond_to? :user_card_id
    params[:user_bank_account_id] = user_bank_account_id if respond_to? :user_bank_account_id

    params
  end

  # Updates the associated `money_transaction` with `self` model details.
  #
  # This method updates the associated `money_transaction` with the sum of `price`s,
  # updating also `mt_comment` describing the days of associated `self`s.
  #
  # @note This is a method that is called after_commit.
  #
  # @see {MoneyTransaction}
  #
  # @return [void]
  #
  def update_money_transaction
    transactable = money_transaction.public_send(model_name.plural)
    price = transactable.sum(:price).round(2)

    money_transaction.update(price:, mt_comment:)
  end

  # Updates or destroys the associated `money_transaction` based on `self`s count.
  #
  # This method checks the count of associated `self`s.
  # In case it is zero, it destroys the associated `money_transaction`.
  # Otherwise, it updates the `money_transaction` using {#update_money_transaction}.
  #
  # @note This is a method that is called after_commit.
  #
  # @see {#update_money_transaction}
  #
  # @return [void]
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
