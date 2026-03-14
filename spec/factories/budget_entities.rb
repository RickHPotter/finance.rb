# frozen_string_literal: true

FactoryBot.define do
  factory :budget_entity do
    entity { custom_create(:entity) }

    trait :different do
      entity { different_custom_create(:entity) }
    end

    trait :random do
      entity { random_custom_create(:entity) }
    end
  end
end

# == Schema Information
#
# Table name: budget_entities
# Database name: primary
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
