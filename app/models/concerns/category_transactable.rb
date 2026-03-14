# frozen_string_literal: true

# Shared functionality for models that can have categories through CategoryTransaction.
module CategoryTransactable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_categories

    # @relationships ...........................................................
    has_many :category_transactions, as: :transactable, dependent: :destroy
    has_many :categories, -> { order(:category_name) }, through: :category_transactions
    accepts_nested_attributes_for :category_transactions, allow_destroy: true, reject_if: :all_blank

    # @callbacks ..............................................................
    before_destroy :remember_categories, if: -> { respond_to?(:category_transactions) }, prepend: true
  end

  # @public_class_methods .....................................................
  def category_transactions_attributes=(attrs)
    self.original_categories = category_transactions.pluck(:category_id).sort
    super
  end

  def category_transactions=(attrs)
    self.original_categories = category_transactions.pluck(:category_id).sort
    super
  end

  def categories=(attrs)
    self.original_categories = categories.ids.sort
    super
  end

  # @return [ActiveRecord::Relation] Helper method for finding custom `categories`.
  #
  def custom_categories
    categories.where("built_in = false OR category_name IN ('INVESTMENT', 'BORROW RETURN')")
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

  protected

  def remember_categories
    self.original_categories = category_transactions.pluck(:category_id).sort
  end
end
