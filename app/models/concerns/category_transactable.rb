# frozen_string_literal: true

# Shared functionality for models that can have categories through CategoryTransaction.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :category_transaction_attributes

    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable, dependent: :destroy
    has_many :categories, through: :category_transactions

    # @callbacks ...............................................................
    before_commit :create_category_transactions, on: :create
    before_update :update_category_transactions
  end

  # @public_class_methods .....................................................
  def custom_categories
    categories.where.not(category_name: ['Exchange', 'Exchange Return'])
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
  # @note The method uses the provided `category_transaction_attributes` to create category transactions
  #   for the transactable.
  # @note This is a method that is called before_commit.
  #
  # @return [void]
  #
  # @see CategoryTransaction
  #
  def create_category_transactions
    return unless category_transaction_attributes&.present?

    category_transaction_attributes.each do |attributes|
      category_transactions << CategoryTransaction.create(attributes.merge(transactable: self))
    end
  end

  # Update category transactions based on the provided `category_transaction_attributes` array of hashes.
  #
  # In case there were category transactions, these get destroyed, and then created again.
  # Otherwise, then nothing happens unless `category_transaction_attributes` is present.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_category_transactions
    return unless category_transaction_attributes

    category_transactions.destroy_all if category_transactions.present?
    create_category_transactions if category_transaction_attributes.present?
  end
end
