# frozen_string_literal: true

# Shared functionality for models that can have entities through EntityTransaction.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @includes ...............................................................
    include Backend::NestedHelper

    # @security (i.e. attr_accessible) ........................................
    attr_accessor :entity_transaction_attributes

    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable, dependent: :destroy
    has_many :entities, through: :entity_transactions

    # @callbacks ...............................................................
    before_validation :check_consistency
    after_validation :update_card_transaction_categories
    before_create :create_entity_transactions
    before_update :update_entity_transactions
  end

  # @public_class_methods .....................................................
  def paying_entities
    entity_transactions.where(is_payer: true).map(&:entity)
  end

  # @protected_instance_methods ...............................................

  protected

  # Checks the consistency of the atributes of `entity_transactions` creation.
  #
  # This method checks if the `entity_transaction_attributes` is present.
  # It then uses the {Backend::NestedHelper#check_array_of_hashes_of} method with the `entity_transaction_attributes`.
  # For each entity_transaction, it finds or initialises a new {EntityTransaction} object based on
  # entity_transaction attribute `entity`, and `self`, which is a {CardTransaction}, as `transactable`.
  #
  # @return [Boolean] Returns true if all `entity_transactions` are valid; otherwise, false with ActiveModel#errors.
  #
  def check_consistency
    return if entity_transaction_attributes.blank?

    check_array_of_hashes_of(entity_transactions: entity_transaction_attributes) do |entity_transaction|
      ent = EntityTransaction.find_or_initialize_by(entity: entity_transaction[:entity], transactable: self)
      true if ent.valid? || entity_transactions.include?(ent)
    end
  end

  # FIXME: i dont even know how, but it looks a bit shit
  # FIXME: ffs, I wrote this about 10 hours ago and I don't remember what the fuck is this about
  def update_card_transaction_categories
    return if errors.any? || entity_transaction_attributes.nil?

    exchange_category_id = user.built_in_category('Exchange').id

    exchange_category_transaction = category_transactions.find do |category_transaction|
      category_transaction.category_id == exchange_category_id
    end

    return exchange_category_transaction&.destroy if entity_transaction_attributes.pluck(:is_payer).none?

    return if exchange_category_transaction

    category_transactions.push(CategoryTransaction.new(category_id: exchange_category_id, transactable: self))
  end

  # Creates `entity_transactions` based on the provided `entity_transaction_attributes` array of hashes.
  #
  # @example Create `entity_transactions` for a {CardTransaction}
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
  #   => a new `entity_transaction` is created for this `card_transaction`
  #
  # @note This is a method that is called before_create.
  # @note The method uses the provided `entity_transaction_attributes` to create `entity_transactions`
  #   for the `transactable`.
  #
  # @see {EntityTransaction}
  #
  # @return [void]
  #
  def create_entity_transactions
    return if entity_transaction_attributes.blank?

    entity_transaction_attributes.each do |attributes|
      ent = EntityTransaction.new(attributes.merge(transactable: self))
      entity_transactions.push(ent) unless entity_transactions.include?(ent)
    end

    destroy_entity_transaction_attributes
  end

  # Updates `entity_transactions` based on the provided `entity_transaction_attributes` array of hashes.
  #
  # In case there were `entity_transactions`, these get destroyed.
  # If `entity_transaction_attributes` is present, then `entity_transactions` are created again.
  # Otherwise, nothing happens.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  def update_entity_transactions
    return unless entity_transaction_attributes

    entity_transactions.destroy_all if entity_transactions.present?
    create_entity_transactions if entity_transaction_attributes.present?
    # entities.reload # Forgive me for I have sinned, touch: true does not work

    destroy_entity_transaction_attributes
  end

  # Destroys `entity_transaction_attributes` so that later updates don't reuse the cached instance
  #
  def destroy_entity_transaction_attributes
    self.entity_transaction_attributes = nil
  end
end
