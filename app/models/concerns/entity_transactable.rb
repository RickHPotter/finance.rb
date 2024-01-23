# frozen_string_literal: true

# Shared functionality for models that can have entities through EntityTransaction.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
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

  # FIXME: DRY
  def check_consistency
    return unless entity_transaction_attributes&.present?

    unless entity_transaction_attributes.is_a?(Array)
      errors.add(:entity_transactions, 'should be an array')
      return false
    end

    entity_transaction_attributes.each do |entity_transaction|
      unless entity_transaction.is_a?(Hash)
        errors.add(:entity_transactions, 'should be an array of hashes')
        return false
      end

      ent = EntityTransaction.find_or_initialize_by(entity: entity_transaction[:entity], transactable: self)
      next if ent.valid? || entity_transactions.include?(ent)

      errors.add(:entity_transactions, 'should be an array of hashes of valid entity transactions')
      return false
    end
  end

  # FIXME: i dont even know how, but it looks a bit shit
  def update_card_transaction_categories
    return if errors.any? || entity_transaction_attributes.nil?

    exchange_category_id = user.categories.find_by(category_name: 'Exchange').id

    exchange_category_transaction = category_transactions.find do |category_transaction|
      category_transaction.category_id == exchange_category_id
    end

    return exchange_category_transaction&.destroy if entity_transaction_attributes.pluck(:is_payer).none?

    return if exchange_category_transaction

    category_transactions.push(CategoryTransaction.new(category_id: exchange_category_id, transactable: self))
  end

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
  #           { exchange_type: :monetary, price: 2.00 },
  #           { exchange_type: :monetary, price: 2.00 }
  #         ]
  #       }
  #     ]
  #   )
  #   => create_entity_transactions is run before_commit
  #   => a new entity transaction is created
  #
  # @note The method uses the  provided `entity_transaction_attributes` to create entity transactions
  #   for the transactable.
  # @note This is a method that is called before_create.
  #
  # @return [void]
  #
  # @see EntityTransaction
  #
  def create_entity_transactions
    return unless entity_transaction_attributes&.present?

    entity_transaction_attributes.each do |attributes|
      ent = EntityTransaction.new(attributes.merge(transactable: self))
      entity_transactions.push(ent) unless entity_transactions.include?(ent)
    end

    destroy_entity_transaction_attributes
  end

  # Update entity transactions based on the provided `entity_transaction_attributes` array of hashes.
  #
  # In case there were entity transactions, these get destroyed, and then created again.
  # Otherwise, then nothing happens unless `entity_transaction_attributes` is present.
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

  def destroy_entity_transaction_attributes
    self.entity_transaction_attributes = nil
  end
end
