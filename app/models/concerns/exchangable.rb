# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module Exchangable
  include Backend::MathsHelper
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :exchange_attributes

    # @relationships ..........................................................
    has_many :exchanges, dependent: :destroy

    # @callbacks ..............................................................
    before_validation :set_exchange_attributes
    before_create :create_exchanges
    before_update :update_exchanges
  end

  # @protected_instance_methods ...............................................

  protected

  # Set `exchange_attributes` to an empty array if `is_payer` is false.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_exchange_attributes
    self.exchange_attributes = [] if is_payer == false
  end

  # Create exchanges based on the provided `exchange_attributes` array of hashes.
  #
  # @example Create exchanges through a CardTransaction
  #   card_transaction = CardTransaction.create(
  #     date: Date.current, user_id: User.first.id,
  #     user_card_id: User.first.user_cards.ids.sample,
  #     ct_description: 'testing', price: 4.00,
  #     month: Date.current.month, year: Date.current.year,
  #     entity_transaction_attributes: [
  #       {
  #         entity_id: User.first.entities.ids.sample,
  #         is_payer: true, price: 4.00,
  #         exchange_attributes: [
  #           { exchange_type: :monetary, price: 2.00 },
  #           { exchange_type: :monetary, price: 2.00 }
  #         ]
  #       }
  #     ]
  #   )
  #   => create_exchanges is run before_create
  #   => two exchanges are created for given entity
  #
  # @note The method uses the provided `exchange_attributes` to create exchanges
  #   for the entity transaction.
  # @note This is a method that is called before_create.
  #
  # @return [void]
  #
  # @see Exchange
  #
  def create_exchanges
    return unless should_have_exchanges?

    exchange_attributes ||= create_default_exchange_attributes

    exchange_attributes.each_with_index do |attributes, index|
      exchanges << Exchange.create(attributes.merge(number: index + 1))
    end

    self.exchanges_count = exchange_attributes.count
  end

  # Update exchanges based on a set of conditions.
  #
  # In case there were no exchanges to begin with, they are created instead of updated.
  # In case there were exchanges, they are deleted and then updated.
  # In case there were exchanges, `is_payer` == false, then the creation of exchanges is avoided.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_exchanges
    return create_exchanges if exchanges.blank? && is_payer

    exchanges.destroy_all
    create_exchanges if should_have_exchanges?
  end

  # Checks whether the model should have exchanges.
  #
  # @return [Boolean] true if the model is the payer and exchanges should be present, false otherwise.
  #
  def should_have_exchanges?
    is_payer && exchanges_count.positive? || exchange_attributes.present?
  end

  # Creates default exchange attributes based on the `price` and `exchanges_count` values.
  #
  # @return [Array<Hash>] an array of default exchange attributes.
  #
  def create_default_exchange_attributes
    prices_array = spread_installments_evenly(price, exchanges_count)
    prices_array.each_with_object [] do |price, array|
      array << { exchange_type: :monetary, price: }
    end
  end
end
