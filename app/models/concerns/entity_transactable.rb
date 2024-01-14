# frozen_string_literal: true

# Shared functionality for models that can produce EntityTransactions.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :entity_transaction_attributes

    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable
    has_many :entities, through: :entity_transactions

    # @callbacks ...............................................................
    before_commit :create_entity_transactions
  end

  # @protected_instance_methods ...............................................

  protected

  # Create entity transactions based on the provided `entity_transaction_attributes` array of hashes.
  #
  # @example Create entity transactions for a CardTransaction
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
  #   => create_entity_transactions is run before_commit
  #   => a new entity transaction is created
  #
  # @note The method uses the  provided `entity_transaction_attributes` to create entity transactions
  #   for the transactable.
  #
  # @return [void]
  #
  # @see EntityTransaction
  #
  def create_entity_transactions
    return if entity_transaction_attributes.blank?

    entity_transaction_attributes.each do |attributes|
      entity_transactions << EntityTransaction.create(attributes.merge(transactable: self))
    end
  end
end
