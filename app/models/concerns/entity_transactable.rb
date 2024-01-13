# frozen_string_literal: true

# Shared functionality for models that can produce EntityTransactions.
module EntityTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :entity_transaction_attributes

    # @relationships ...........................................................
    has_many :entity_transactions, as: :transactable
    has_many :entities, through: :entity_transactions

    # @callbacks ...............................................................
    before_save :create_entity_transactions
  end

  # @protected_instance_methods ...............................................

  protected

  def create_entity_transactions
    return if entity_transaction_attributes.blank?

    entity_transaction_attributes.each do |attributes|
      entity_transactions << EntityTransaction.create(attributes.merge(transactable: self))
    end
  end
end
