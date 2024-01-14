# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module Exchangable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :exchange_attributes

    # @relationships ..........................................................
    has_many :exchanges

    # @callbacks ..............................................................
    before_create :create_exchanges
  end

  # @protected_instance_methods ...............................................

  protected

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
  #           { exchange_type: :monetary, amount_to_be_returned: 2.00, amount_returned: 0.00 },
  #           { exchange_type: :monetary, amount_to_be_returned: 2.00, amount_returned: 0.00 }
  #         ]
  #       }
  #     ]
  #   )
  #   => create_exchanges is run before_create
  #   => two exchanges are created for given entity
  #
  # @note The method uses the  provided `exchange_attributes` to create exchanges
  #   for the entity transaction.
  #
  # @return [void]
  #
  # @see Exchange
  #
  def create_exchanges
    return if exchange_attributes.blank? || is_payer == false

    exchange_attributes.each_with_index do |attributes, index|
      exchanges << Exchange.create(attributes.merge(number: index + 1))
    end

    self.exchanges_count = exchange_attributes.count
  end
end
