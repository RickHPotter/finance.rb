# frozen_string_literal: true

class BudgetCategory < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :budget
  belongs_to :category

  # @validations ..............................................................
  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: budget_categories
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  budget_id   :bigint           not null, indexed, uniquely indexed => [category_id]
#  category_id :bigint           not null, indexed, uniquely indexed => [budget_id]
#
# Indexes
#
#  index_budget_categories_on_budget_id      (budget_id)
#  index_budget_categories_on_category_id    (category_id)
#  index_budget_categories_on_composite_key  (budget_id,category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (budget_id => budgets.id)
#  fk_rails_...  (category_id => categories.id)
#
