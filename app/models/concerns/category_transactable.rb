# frozen_string_literal: true

# Shared functionality for models that can have categories through CategoryTransaction.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @includes ...............................................................
    include Backend::NestedHelper

    # @security (i.e. attr_accessible) ........................................
    attr_accessor :category_transaction_attributes

    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable, dependent: :destroy
    has_many :categories, through: :category_transactions

    # @callbacks ...............................................................
    before_validation :check_consistency
    before_create :create_category_transactions
    before_update :update_category_transactions
  end

  # @public_class_methods .....................................................
  def custom_categories
    categories.where(built_in: false)
  end

  # @protected_instance_methods ...............................................

  protected

  # Checks the consistency of the atributes of `category_transactions` creation.
  #
  # This method checks if the `category_transaction_attributes` is present.
  # It then uses the {Backend::NestedHelper#check_array_of_hashes_of} method with the `category_transaction_attributes`.
  # For each category_transaction, it finds or initialises a new {CategoryTransaction} object based on
  # category_transaction attribute `category`, and `self`, which is a {CardTransaction}, as `transactable`.
  #
  # @return [Boolean] Returns true if all `category_transactions` are valid; otherwise, false with ActiveModel#errors.
  #
  def check_consistency
    return if category_transaction_attributes.blank?

    check_array_of_hashes_of(category_transactions: category_transaction_attributes) do |category_transaction|
      cat = CategoryTransaction.find_or_initialize_by(category: category_transaction[:category], transactable: self)
      true if cat.valid? || category_transactions.include?(cat)
    end
  end

  # Creates `category_transactions` based on the provided `category_transaction_attributes` array of hashes.
  #
  # @example Create `category_transactions` for a {CardTransaction}
  #   card_transaction = CardTransaction.create(
  #     date: Date.current, user_id: User.first.id,
  #     user_card_id: User.first.user_cards.ids.sample,
  #     ct_description: 'He was flying', price: 4.00,
  #     month: Date.current.month, year: Date.current.year,
  #     category_transaction_attributes: [
  #       { category_id: User.first.categories.first.id },
  #       { category_id: User.first.categories.second.id }
  #     ]
  #   )
  #   => two new `category_transactions` are created for this `card_transaction`
  #
  # @note This is a method that is called before_create.
  # @note The method uses the provided `category_transaction_attributes` to create `category_transactions`
  #   for the `transactable`.
  #
  # @see {CategoryTransaction}
  #
  # @return [void]
  #
  def create_category_transactions
    return if category_transaction_attributes.blank?

    category_transaction_attributes.each do |attributes|
      cat = CategoryTransaction.new(attributes.merge(transactable: self))
      category_transactions.push(cat) unless category_transactions.include?(cat)
    end

    destroy_category_transaction_attributes
  end

  # Updates `category_transactions` based on the provided `category_transaction_attributes` array of hashes.
  #
  # In case there were `category_transactions`, these get destroyed.
  # If `category_transaction_attributes` is present, then `category_transactions` are created again.
  # Otherwise, nothing happens.
  # For reason that defeats the purpose of trying to live peacefully, I have to reload the `categories`,
  # because, for some ✨fucked✨ up reason: +touch: true+ does not work.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_category_transactions
    return unless category_transaction_attributes

    category_transactions.destroy_all if category_transactions.present?
    create_category_transactions if category_transaction_attributes.present?
    categories.reload # Forgive me for I have sinned, touch: true does not work

    destroy_category_transaction_attributes
  end

  # Destroys `category_transaction_attributes` so that later updates don't reuse the cached instance
  #
  def destroy_category_transaction_attributes
    self.category_transaction_attributes = nil
  end
end
