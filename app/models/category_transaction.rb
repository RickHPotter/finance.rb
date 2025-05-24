# frozen_string_literal: true

class CategoryTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :category, touch: true
  belongs_to :transactable, polymorphic: true

  # @validations ..............................................................
  validates :category_id, uniqueness: { scope: %i[transactable_type transactable_id] }

  # @callbacks ................................................................
  after_destroy :update_count_and_total

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  def update_count_and_total
    category.update_card_transactions_count_and_total
    category.update_cash_transactions_count_and_total
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: category_transactions
#
#  id                :bigint           not null, primary key
#  transactable_type :string           not null, indexed => [category_id, transactable_id], indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  category_id       :bigint           not null, indexed, indexed => [transactable_type, transactable_id]
#  transactable_id   :bigint           not null, indexed => [category_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_category_transactions_on_category_id    (category_id)
#  index_category_transactions_on_composite_key  (category_id,transactable_type,transactable_id) UNIQUE
#  index_category_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
