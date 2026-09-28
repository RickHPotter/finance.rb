# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    category_name { "FOOD" }
    colour { "#f1f5f9" }
    text_colour_mode { "automatic" }
    user { custom_create(:user) }

    trait :different do
      category_name { "TRANSPORT" }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:category_name) { |n| "#{Faker::Hobby.activity} #{rand(10..99)} #{n}".upcase }
      user { random_custom_create(:user) }
    end

    trait :parent_category do
      category_name { "HOME" }
    end

    trait :child_category do
      category_name { "SUPPLIES" }
      parent_category { association(:category, user:) }
    end

    trait :subcategory do
      child_category
    end
  end
end

# == Schema Information
#
# Table name: categories
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  category_name           :string           not null, uniquely indexed => [user_id, parent_category_id]
#  colour                  :string           default("#f1f5f9"), not null
#  text_colour             :string
#  text_colour_mode        :string           default("automatic"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  parent_category_id      :bigint           indexed, uniquely indexed => [user_id, category_name]
#  user_id                 :bigint           not null, indexed, uniquely indexed => [parent_category_id, category_name]
#
# Indexes
#
#  index_categories_on_parent_category_id       (parent_category_id)
#  index_categories_on_user_id                  (user_id)
#  index_categories_on_user_id_parent_and_name  (user_id,parent_category_id,category_name) UNIQUE NULLS NOT DISTINCT
#
# Foreign Keys
#
#  fk_rails_...  (parent_category_id => categories.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id)
#
