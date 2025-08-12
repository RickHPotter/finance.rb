# frozen_string_literal: true

class BudgetEntity < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :budget
  belongs_to :entity

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
# Table name: budget_entities
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  budget_id  :bigint           not null, indexed, uniquely indexed => [entity_id]
#  entity_id  :bigint           not null, uniquely indexed => [budget_id], indexed
#
# Indexes
#
#  index_budget_entities_on_budget_id      (budget_id)
#  index_budget_entities_on_composite_key  (budget_id,entity_id) UNIQUE
#  index_budget_entities_on_entity_id      (entity_id)
#
# Foreign Keys
#
#  fk_rails_...  (budget_id => budgets.id)
#  fk_rails_...  (entity_id => entities.id)
#
