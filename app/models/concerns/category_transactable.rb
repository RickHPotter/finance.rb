# frozen_string_literal: true

# Shared functionality for models that can have categories through CategoryTransaction.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable, dependent: :destroy
    has_many :categories, through: :category_transactions
    accepts_nested_attributes_for :category_transactions, allow_destroy: true, reject_if: :all_blank
  end

  # @public_class_methods .....................................................

  # @return [ActiveRecord::Relation] Helper method for finding custom `categories`.
  #
  def custom_categories
    categories.where(built_in: false)
  end

  # @param [Hash] options.
  #
  # @return [ActiveRecord::Relation] Helper method for finding built-in `category_transactions`.
  #
  def built_in_category_transactions_by(options = {})
    category_transactions.includes(:category).where(options).where(categories: { built_in: true })
  end

  # @param [Hash] options
  #
  # @return [ActiveRecord::Relation] Helper method for finding built-in `categories`.
  #
  def built_in_categories_by(options = {})
    categories.where(options.merge(built_in: true))
  end

  # @protected_instance_methods ...............................................
end
