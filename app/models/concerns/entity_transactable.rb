# frozen_string_literal: true

# Shared functionality for models that can have entities through EntityTransaction.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_entities

    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable, dependent: :destroy
    has_many :entities, -> { order(:entity_name) }, through: :entity_transactions
    accepts_nested_attributes_for :entity_transactions, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_destroy :remember_entities, if: -> { respond_to?(:entity_transactions) }, prepend: true
  end

  # @public_class_methods .....................................................
  def entity_transactions_attributes=(attrs)
    self.original_entities = entity_transactions.pluck(:entity_id).sort
    super
  end

  def entity_transactions=(attrs)
    self.original_entities = entity_transactions.pluck(:entity_id).sort
    super
  end

  def entities=(attrs)
    self.original_entities = entities.ids.sort
    super
  end

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

  def remember_entities
    self.original_entities = entity_transactions.pluck(:entity_id).sort
  end
end
