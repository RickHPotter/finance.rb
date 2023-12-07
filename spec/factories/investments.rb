# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :integer          not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  money_transaction_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :investment do
    price { 1.12 }
    date { Date.new(2023, 12, 16) }

    association :user
    category { custom_create(model: :category, reference: { user: }) }
    user_bank_account { custom_create(model: :user_bank_account, reference: { user: }) }
    money_transaction { custom_create(model: :money_transaction, reference: { user: }) }

    trait :different do
      price { 0.52 }
      date { Date.new(2023, 11, 26) }

      association :user, :different
      category { custom_create(model: :category, traits: [:different], reference: { user: }) }
      user_bank_account { custom_create(model: :user_bank_account, traits: [:different], reference: { user: }) }
      money_transaction { custom_create(model: :money_transaction, traits: [:different], reference: { user: }) }
    end

    trait :random do
      price { Faker::Number.decimal(l_digits: rand(0..1)) }
      date { Faker::Date.between(from: 1.months.ago, to: Date.today) }

      association :user, :random
      category { custom_create(model: :category, traits: [:random], reference: { user: }) }
      user_bank_account { custom_create(model: :user_bank_account, traits: [:random], reference: { user: }) }
      money_transaction { custom_create(model: :money_transaction, traits: [:random], reference: { user: }) }
    end
  end
end
