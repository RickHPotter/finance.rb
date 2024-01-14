# frozen_string_literal: true

# Shared functionality for models that can have categories.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :category_transaction_attributes

    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable
    has_many :categories, through: :category_transactions

    # @callbacks ...............................................................
    before_commit :create_category_transactions
  end

  # @protected_instance_methods ...............................................

  protected

  # Create category transactions based on the provided `category_transaction_attributes` array of hashes.
  #
  # @example Create category transactions for a CardTransaction
  #   card_transaction = CardTransaction.create(
  #     date: Date.current, user_id: User.first.id,
  #     user_card_id: User.first.user_cards.ids.sample,
  #     ct_description: 'testing', price: 4.00,
  #     month: Date.current.month, year: Date.current.year,
  #     category_transaction_attributes: [
  #       { category_id: User.first.categories.first.id },
  #       { category_id: User.first.categories.second.id }
  #     ]
  #   )
  #   => create_category_transactions is run before_commit
  #   => two new category transactions are created
  #
  # @note The method uses the  provided `category_transaction_attributes` to create category transactions
  #   for the transactable.
  #
  # @return [void]
  #
  # @see CategoryTransaction
  #
  def create_category_transactions
    return if category_transaction_attributes.blank?

    category_transaction_attributes.each do |attributes|
      category_transactions << CategoryTransaction.create(attributes.merge(transactable: self))
    end
  end
end
