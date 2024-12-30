# frozen_string_literal: true

# Shared functionality for models that are accumulated to a single CashTransaction.
module MoneyTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :previous_cash_transaction_id

    # @relationships ..........................................................
    belongs_to :cash_transaction, optional: true

    # @callbacks ..............................................................
    before_save :attach_cash_transaction
    after_save :fix_cash_transaction
    after_commit :update_cash_transaction, on: %i[create update]
    after_commit :update_or_destroy_cash_transaction, on: :destroy
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Assigns a `previous_cash_transaction_id` and attachs `cash_transaction` to `self`, based on certain attributes, and links it to `self`.
  #
  # @note This is a method that is called before_save.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def attach_cash_transaction
    self.previous_cash_transaction_id = cash_transaction&.id
    self.cash_transaction = CashTransaction.joins(:category_transactions).find_by(cash_transaction_params.merge(category_transactions:)) ||
                            CashTransaction.create(cash_transaction_params.merge(price:, category_transactions_attributes:, date: cash_transaction_date))
  end

  # Deals with change of `cash_transaction` due to change of self FKs, by performing necessary operations to the `previous_cash_transaction`
  # when such is switched to another `cash_transaction`.
  #
  # @note This is a method that is called before_save.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def fix_cash_transaction
    previous_cash_transaction = CashTransaction.find_by(id: previous_cash_transaction_id)
    return if previous_cash_transaction.nil?
    return if previous_cash_transaction == cash_transaction

    previous_cash_transaction.investments&.first&.touch
    previous_cash_transaction.installments&.first&.touch

    association = cash_transaction.cash_transaction_type.underscore.pluralize
    previous_cash_transaction.destroy if previous_cash_transaction.public_send(association).empty?
  end

  # Updates the associated `cash_transaction` with `self` model details.
  #
  # Updates the associated `cash_transaction` with the sum of `price`s,
  # updating also `comment` describing the days of associated `self`s.
  #
  # @note This is a method that is called after_commit.
  #
  # @see {CashTransaction}.
  #
  # @return [void].
  #
  def update_cash_transaction
    transactable = cash_transaction.public_send(model_name.plural)
    price = transactable.sum(:price).round(2)

    cash_transaction.update(price:, comment:)
  end

  # Updates or destroys the associated `cash_transaction` based on `self`s count.
  #
  # Checks the `count` of associated `self`s.
  # In case it is zero, it destroys the associated `cash_transaction`.
  # Otherwise, it updates the `cash_transaction` using {#update_cash_transaction}.
  #
  # @note This is a method that is called after_commit.
  #
  # @see {#update_cash_transaction}.
  #
  # @return [void].
  #
  def update_or_destroy_cash_transaction
    return if cash_transaction.nil?

    transactable = cash_transaction.public_send(model_name.plural)
    if transactable.count.zero?
      cash_transaction.destroy
    else
      update_cash_transaction
    end
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `cash_transaction`.
  #
  def cash_transaction_params
    params = {
      description:,
      month:,
      year:,
      user_id:,
      cash_transaction_type: model_name.name
    }
    params[:user_card_id] = user_card_id if respond_to? :user_card_id
    params[:user_bank_account_id] = user_bank_account_id if respond_to? :user_bank_account_id

    params
  end
end
