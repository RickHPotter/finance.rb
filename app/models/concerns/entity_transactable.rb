# frozen_string_literal: true

# Shared functionality for models that can have entities through EntityTransaction.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable, dependent: :destroy
    has_many :entities, -> { order(:entity_name) }, through: :entity_transactions
    accepts_nested_attributes_for :entity_transactions, allow_destroy: true, reject_if: :all_blank
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
end
