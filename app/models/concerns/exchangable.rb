# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module Exchangable
  extend ActiveSupport::Concern

  included do
    # @includes ...............................................................
    include Backend::NestedHelper
    include Backend::MathsHelper

    # @security (i.e. attr_accessible) ........................................
    attr_accessor :exchange_attributes

    # @relationships ..........................................................
    has_many :exchanges, dependent: :destroy, counter_cache: :exchanges_count

    # @callbacks ..............................................................
    before_validation :check_consistency
    before_validation :set_exchange_attributes
    after_validation :update_entity_transaction_status
    before_create :create_exchanges
    before_update :update_exchanges
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  # Checks the consistency of the atributes of `exchanges` creation.
  #
  # This method checks if the `exchange_attributes` are present and if the object is a payer.
  # It then uses the {Backend::NestedHelper#check_array_of_hashes_of} method with the `exchange_attributes`.
  # For each exchange, it initialises a new {Exchange} object based on the exchange merged with
  # the `self`, which is an {EntityTransaction}, as `entity_transaction`.
  #
  # @return [Boolean] Returns true if all `exchanges` are valid; otherwise, it returns false with ActiveModel#errors.
  #
  def check_consistency
    return if exchange_attributes.blank?
    return unless is_payer

    check_array_of_hashes_of(exchanges: exchange_attributes) do |exchange|
      exc = Exchange.new(exchange.merge(entity_transaction: self))
      true if exc.valid?
    end
  end

  # Sets the `exchange_attributes` based on `is_payer` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_exchange_attributes
    self.exchange_attributes ||= [] unless is_payer
  end

  # Sets the `status` of the `entity_transaction` based on the existing `exchanges`.
  #
  # @note This is a method that is called after_validation.
  #
  # @return [void]
  #
  def update_entity_transaction_status
    return if errors.any?

    return self.status = :finished if exchanges.map(&:exchange_type).uniq == [ "non_monetary" ]

    self.status = :pending
  end

  # Creates `exchanges` based on the provided `exchange_attributes` array of hashes.
  #
  # @example Create `exchanges` through a {CardTransaction}
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
  #   => two `exchanges` are created for this `card_transaction` through `entity_transaction`
  #
  # @note This is a method that is called before_create.
  # @note The method uses the provided `exchange_attributes` to create `exchanges`
  #   for the `entity_transaction`.
  #
  # @see {Exchange}
  #
  # @return [void]
  #
  def create_exchanges
    return if exchange_attributes.blank?

    exchange_attributes.each_with_index do |attributes, index|
      exc = Exchange.new(attributes.merge(number: index + 1))
      exchanges.push(exc) unless exchanges.include?(exc)
    end

    destroy_exchange_attributes
  end

  # Updates `exchanges` based on a set of conditions.
  #
  # In case `exchange_attributes` is nil, nothing happens.
  # In case `exchange_attributes` is not nil, `exchanges` are deleted, then the process is
  # delegated to {#create_exchanges} method that will only create new `exchanges` if
  # `exchange_attributes` is not empty.
  #
  # @note This is a method that is called before_update.
  #
  # @see {#set_exchange_attributes} to check that exchange_attributes can be ignored in the initialisation
  #
  # @return [void]
  #
  def update_exchanges
    return unless exchange_attributes

    exchanges.destroy_all
    create_exchanges
  end

  # Destroys `exchange_attributes` so that later updates don't reuse the cached instance
  #
  def destroy_exchange_attributes
    self.exchange_attributes = nil
  end
end
