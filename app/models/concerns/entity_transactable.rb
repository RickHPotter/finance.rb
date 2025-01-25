# frozen_string_literal: true

# Shared functionality for models that can have entities through EntityTransaction.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable, dependent: :destroy
    has_many :entities, through: :entity_transactions
    accepts_nested_attributes_for :entity_transactions, allow_destroy: true, reject_if: :all_blank

    # @callbacks ...............................................................
    after_save :update_card_transaction_categories, if: -> { instance_of?(CardTransaction) }
  end

  # @public_class_methods .....................................................

  # @return [ActiveRecord::Relation] Helper method to return the paying `entity_transactions`.
  #
  def paying_transactions
    entity_transactions.where(is_payer: true)
  end

  # @return [ActiveRecord::Relation] Helper method to return the non-paying `entity_transactions`.
  #
  def non_paying_transactions
    entity_transactions.where(is_payer: false)
  end

  # @return [ActiveRecord::Relation] Helper method to return the `entities` of paying `entity_transactions`.
  #
  def paying_entities
    paying_transactions.map(&:entity)
  end

  # @return [ActiveRecord::Relation] Helper method to return the `entities` of `non-paying `entity_transactions`.
  #
  def non_paying_entities
    non_paying_transactions.map(&:entity)
  end

  # @protected_instance_methods ...............................................

  protected

  # Handles the `category` of such `transaction` based on the existing `exchanges`.
  #
  # @note This is a method that is called after_save.
  #
  # return [void].
  #
  def update_card_transaction_categories
    return if defined?(imported) && imported

    exchange_category_id = user.built_in_category("EXCHANGE").id

    exchange_cat = built_in_category_transactions_by(category_id: exchange_category_id)
    payers = entity_transactions.pluck(:is_payer)

    return exchange_cat.map(&:destroy) if exchange_cat.present? && payers.none?

    category_transactions << CategoryTransaction.new(category_id: exchange_category_id) if payers.any?
  end
end
