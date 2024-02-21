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
  # Helper method for finding custom categories
  #
  # @return [ActiveRecord::Relation]
  #
  def custom_categories
    categories.where(built_in: false)
  end

  # Helper method for finding built-in category transactions
  #
  # @param [Hash] options
  #
  # @return [ActiveRecord::Relation]
  #
  def built_in_category_transactions_by(options = {})
    category_transactions.includes(:category).where(options).where(categories: { built_in: true })
  end

  # Helper method for finding built-in categories
  #
  # @param [Hash] options
  #
  # @return [ActiveRecord::Relation]
  #
  def built_in_categories_by(options = {})
    categories.where(options.merge(built_in: true))
  end

  # @protected_instance_methods ...............................................
end
