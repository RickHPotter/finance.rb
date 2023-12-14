# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                     :integer          not null, primary key
#  mt_description         :string           not null
#  mt_comment             :string
#  date                   :date             not null
#  month                  :integer          not null
#  year                   :integer          not null
#  starting_price         :decimal(, )      not null
#  price                  :decimal(, )      not null
#  money_transaction_type :string
#  user_id                :integer          not null
#  category_id            :integer          not null
#  user_bank_account_id   :integer
#  user_card_id           :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
FactoryBot.define do
  factory :money_transaction do
    mt_description { 'Meat' }
    mt_comment { 'Barbecue at Aunt\'s' }
    date { Date.new 2023, 12, 16 }
    price { 29.72 }
    month { 12 }
    year { 2023 }

    association :user
    category { custom_create(model: :category, reference: { user: }) }
    user_bank_account { custom_create(model: :user_bank_account, reference: { user: }) }

    trait :different do
      mt_description { 'HotWheels' }
      mt_comment { 'Toy for brother-in-law' }
      price { 6.50 }
      month { 1 }
      year { 2024 }

      association :user, :different
      category { custom_create(model: :category, traits: [:different], reference: { user: }) }
      user_bank_account { custom_create(model: :user_bank_account, traits: [:different], reference: { user: }) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.today) }
      mt_description { Faker::Lorem.sentence }
      mt_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }

      association :user, :random
      category { custom_create(model: :category, traits: [:random], reference: { user: }) }
      user_bank_account { custom_create(model: :user_bank_account, traits: [:random], reference: { user: }) }
    end
  end
end
