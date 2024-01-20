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
    before_validation :check_consistency
    before_create :create_category_transactions
    before_update :update_category_transactions
  end

  # @public_class_methods .....................................................
  def custom_categories
    categories.where.not(category_name: ['Exchange', 'Exchange Return'])
  end

  # @protected_instance_methods ...............................................

  protected

  # FIXME: DRY
  def check_consistency
    return unless category_transaction_attributes&.present?

    unless category_transaction_attributes.is_a?(Array)
      errors.add(:category_transactions, 'should be an array')
      return false
    end

    category_transaction_attributes.each do |category_transaction|
      unless category_transaction.is_a?(Hash)
        errors.add(:category_transactions, 'should be an array of hashes')
        return false
      end

      unless CategoryTransaction.new(category: category_transaction[:category], transactable: self).valid?
        errors.add(:category_transactions, 'should be an array of hashes of valid category transactions')
        return false
      end
    end
  end

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
  # @note This is a method that is called before_create.
  #
  # @return [void]
  #
  # @see CategoryTransaction
  #
  def create_category_transactions
    return unless category_transaction_attributes&.present?

    category_transaction_attributes.each do |attributes|
      cat = CategoryTransaction.new(attributes.merge(transactable: self))
      category_transactions.push(cat) unless category_transactions.include?(cat)
    end

    destroy_category_transaction_attributes
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
    categories.reload # Forgive me for I have sinned, touch: true does not work

    destroy_category_transaction_attributes
  end

  def destroy_category_transaction_attributes
    self.category_transaction_attributes = nil
  end
end
