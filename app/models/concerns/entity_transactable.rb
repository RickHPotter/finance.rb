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
    after_save :update_card_transaction_categories
  end

  # @public_class_methods .....................................................
  def paying_entities
    entity_transactions.where(is_payer: true).map(&:entity)
  end

  def paying_transactions
    entity_transactions.where(is_payer: true)
  end

  def non_paying_transactions
    entity_transactions.where(is_payer: false)
  end

  def non_paying_entities
    entity_transactions.where(is_payer: false).map(&:entity)
  end

  # @protected_instance_methods ...............................................

  protected

  # TODO: add docs
  def update_card_transaction_categories
    return unless instance_of? CardTransaction

    exchange_category_id = user.built_in_category("Exchange").id

    payers = entity_transactions.pluck(:is_payer)
    exchange_cat = built_in_category_transactions_by(category_id: exchange_category_id)

    if exchange_cat.present?
      return if payers.any?

      exchange_cat.map(&:destroy)
    else
      return if payers.none?

      category_transactions << CategoryTransaction.new(category_id: exchange_category_id)
    end
  end
end
