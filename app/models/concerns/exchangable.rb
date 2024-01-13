# frozen_string_literal: true

# Shared functionality for models that relate to Exchange.
module Exchangable
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :exchanges, as: :exchangable

    # @callbakcs ..............................................................
    # before_validation :set_exchanges_count, if: exchanges.present?

    after_save :create_exchanges, if: -> { entities_exchanges_arr.present? }
    after_save :update_exchanges, if: -> { entities_exchanges_arr.present? }
  end

  # @protected_instance_methods ...............................................

  protected

  def set_exchanges_count
    self.exchanges_count = exchanges_hash.count
  end

  # Create exchanges based on the provided `entities_exchanges_arr`.
  #
  # @example Create exchanges for a CardTransaction
  #   card_transaction = CardTransaction.create(
  #     price: 125,
  #     entities_exchanges_arr: [
  #       { entity_id: 10, exchanges: [ { amount_to_be_returned: 30, amount_returned: 0 } ] },
  #       { entity_id: 12, exchanges: [ { amount_to_be_returned: 30, amount_returned: 0 },
  #                                     { amount_to_be_returned: 20, amount_returned: 0 } ] },
  #       { entity_id: 31, exchanges: [ { amount_to_be_returned: 50, amount_returned: 0 } ] },
  #     ],
  #     ...
  #   )
  #   card_transaction.entities.ids
  #   => [10, 12, 31]
  #   card_transaction.exchanges.count
  #   => 3
  #
  # # TODO: This will be useful for when MoneyTransaction can handle exchanges.
  # @note The method uses the `exchange_id` and `exchange_type` attributes
  #   along with the provided `exchange_prices_arr` to create exchanges for the Transaction.
  #
  # @return [void]
  #
  # @see Exchange
  #
  def create_exchanges
    exchange_prices_arr.each_with_index do |price, number|
      exchanges << Exchange.create(
        entity:,
        exchange_type: :monetary,
        number: number + 1,
        amount_to_be_returned: price,
        amount_returned: amounts_returned_arr[number] || 0.00
      )
    end
  end

  # FIXME: needs doc
  def update_exchanges
    exchanges.each_with_index do |exchange, index|
      exchange.update(
        amount_returned: amounts_returned_arr[index],
        amount_to_be_returned: exchange_prices_arr[index]
      )
    end
  end

  # NOTE: At some point, I will have to create a philosophy that is
  # going to be the way things are done in this app. And not just for
  # this concern / system, but for all of them, in the same way that
  # Elixir language uses the immutability philosophy.
  # For example, I have two options here:
  #   1. When changing the number of exchanges, then that would mean
  #      building all exchanges from scratch. Losing History.
  #   2. When changing the number of exchanges, then that would mean
  #      keeping and rewriting existing changes, zeroing the ones that
  #      should not exist anymore, and so on, in a manner that prevents
  #      losing history at all cost (db size, model poluttion, etc.).
  # FIXME: needs doc
  def prepare_for_update_exchanges
    return update_exchanges if exchange_prices_arr.size != exchanges.size

    exchanges.destroy_all
    create_exchanges
  end
end
