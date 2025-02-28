# frozen_string_literal: true

FactoryBot.define do
  factory :budget_entity do
    transactable { custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
    category { custom_create(:category, options: { user: transactable.user }) }

    trait :different do
      transactable { different_custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
      category { different_custom_create(:category, options: { user: transactable.user }) }
    end

    trait :random do
      transactable { random_custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
      category { random_custom_create(:category, options: { user: transactable.user }) }
    end
  end
end

# == Schema Information
#
# Table name: budget_entities
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  budget_id  :bigint           not null, indexed, indexed => [entity_id]
#  entity_id  :bigint           not null, indexed => [budget_id], indexed
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
