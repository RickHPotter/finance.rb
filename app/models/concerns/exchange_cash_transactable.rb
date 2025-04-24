# frozen_string_literal: true

# Shared functionality for models that can produce CashTransactions.
module ExchangeCashTransactable # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    enum :bound_type, { standalone: "standalone", card_bound: "card_bound" }

    # @extends ................................................................
    delegate :transactable, to: :entity_transaction
    delegate :user, to: :transactable

    # @relationships ..........................................................
    belongs_to :cash_transaction, optional: true

    # @callbacks ..............................................................
    after_validation :update_entity_transaction_status, on: :update
    before_create :create_cash_transaction, if: :monetary?
    before_update :update_cash_transaction, if: :monetary?
    before_update :destroy_cash_transaction, if: :non_monetary?
    before_destroy :update_or_destroy_cash_transaction, if: -> { cash_transaction.present? }
  end

  # @class_methods ............................................................
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
    if standalone?
      self.cash_transaction = CashTransaction.create(cash_transaction_params)
      update_cash_transaction_and_installment(updated_price: cash_transaction.price)
      return
    end

    existing_cash_transaction = user.cash_transactions.joins(:categories, :entities).find_by(card_bound_cash_transaction_conditions)

    if existing_cash_transaction
      self.cash_transaction = existing_cash_transaction
      update_cash_transaction_and_installment(updated_price: exchanges_price + price)
      return
    end

    self.cash_transaction = CashTransaction.create(card_bound_cash_transaction_params)
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

    if changes[:bound_type].nil?
      return if changes[:price].present?

      cash_transaction_price = exchanges_price(with_updated_price: true)
      update_cash_transaction_and_installment(updated_price: cash_transaction_price)
    else
      if standalone?
        update_cash_transaction_and_installment(updated_price: exchanges_price - price)
      else
        destroy_cash_transaction
      end

      create_cash_transaction
    end
  end

  # Sets `cash_transaction_id` to nil if `exchange_type` has changed to `non_monetary`.
  # It then proceeds to destroy the associated `cash_transaction`.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void].
  #
  def destroy_cash_transaction
    return if cash_transaction.nil?

    should_destroy = standalone? || cash_transaction.exchanges.ids == [ id ]

    if should_destroy
      order_id = cash_transaction.cash_installments.first.order_id
      _destroy_cash_transaction
      user.cash_installments.where(order_id: 0..(order_id - 1)).order(:order_id).last&.save
    else
      update_cash_transaction_and_installment(updated_price: exchanges_price - price)
    end
  end

  # Sets `cash_transaction_id` to nil if the `EXCHANGE RETURN` category has been removed.
  # It then proceeds to destroy the associated `cash_transaction`.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void].
  #
  def update_or_destroy_cash_transaction
    sibling_exchanges = Exchange.where(cash_transaction_id: cash_transaction.id).where.not(id:)

    if sibling_exchanges.empty?
      _destroy_cash_transaction
    else
      cash_transaction.update_columns(price: sibling_exchanges.sum(:price))
      cash_transaction.cash_installments.first&.update(price: sibling_exchanges.sum(:price))
    end
  end

  def update_cash_transaction_and_installment(updated_price:)
    cash_transaction.update_columns(price: updated_price)
    cash_transaction.cash_installments.first.update(price: updated_price)
  end

  def exchanges_price(with_updated_price: false)
    price = cash_transaction.exchanges.sum(:price)
    return price if with_updated_price == false || changes[:price].nil?

    price - changes[:price][0] + changes[:price][1]
  end

  def date
    if transactable.is_a?(CardTransaction)
      transactable.card_payment_date + (number - 1).months
    else
      transactable.date + 1.month + (number - 1).months
    end
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `cash_transaction`.
  #
  def cash_transaction_params
    reference_date = Date.new(transactable.year, transactable.month, 1) + (number - 1).months
    year           = reference_date.year
    month          = reference_date.month

    transactable
      .slice(:description, :user_card_id)
      .merge(starting_price:,
             price:,
             date:,
             year:,
             month:,
             user_id: user.id,
             cash_transaction_type: model_name.name,
             category_transactions: FactoryBot.build_list(:category_transaction, 1, transactable: self, category: user.built_in_category("EXCHANGE RETURN")),
             entity_transactions: FactoryBot.build_list(:entity_transaction, 1, transactable: self, entity: entity_transaction.entity))
  end

  def card_bound_cash_transaction_params
    cash_transaction_params.merge(description: transactable.user_card.user_card_name)
  end

  def cash_transaction_conditions
    params = cash_transaction_params
    params[:categories] = { id: params.delete(:category_transactions).pluck(:category_id) }
    params[:entities] = { id: params.delete(:entity_transactions).pluck(:entity_id) }

    params.delete(:categories) if params[:categories][:id].empty?
    params.delete(:entities) if params[:entities][:id].empty?

    params.without(:starting_price, :price, :date)
  end

  def card_bound_cash_transaction_conditions
    cash_transaction_conditions.merge(description: transactable.user_card.user_card_name)
  end

  def _destroy_cash_transaction
    previous_cash_transaction_id = cash_transaction_id
    update_columns(cash_transaction_id: nil)

    CashTransaction.find(previous_cash_transaction_id).destroy
  end
end
