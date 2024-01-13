# frozen_string_literal: true

# Shared functionality for models that can have categories.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :category_transaction_attributes

    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable
    has_many :categories, through: :category_transactions

    # @callbacks ...............................................................
    before_commit :create_category_transactions
  end

  # @protected_instance_methods ...............................................

  protected

  def create_category_transactions
    return if category_transaction_attributes.blank?

    category_transaction_attributes.each do |attributes|
      category_transactions << CategoryTransaction.create(attributes.merge(transactable: self))
    end
  end
end
