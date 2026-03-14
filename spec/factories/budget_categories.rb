# frozen_string_literal: true

FactoryBot.define do
  factory :budget_category do
    category { custom_create(:category) }

    trait :different do
      category { different_custom_create(:category) }
    end

    trait :random do
      category { random_custom_create(:category) }
    end
  end
end

# == Schema Information
#
# Table name: budget_categories
# Database name: primary
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
