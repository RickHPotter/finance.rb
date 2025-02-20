# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    category_name { "FOOD" }
    user { custom_create(:user) }

    trait :different do
      category_name { "TRANSPORT" }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:category_name) { |n| "#{Faker::Hobby.activity} #{rand(10..99)} #{n}".upcase }
      user { random_custom_create(:user) }
    end
  end
end

# == Schema Information
#
# Table name: categories
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  category_name           :string           not null, indexed => [user_id]
#  colour                  :string           default("white"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed, indexed => [category_name]
#
# Indexes
#
#  index_categories_on_user_id           (user_id)
#  index_category_name_on_composite_key  (user_id,category_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
