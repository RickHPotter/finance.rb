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
  def custom_categories
    categories.where(built_in: false)
  end

  # @protected_instance_methods ...............................................
end
