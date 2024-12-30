# frozen_string_literal: true

# == Schema Information
#
# Table name: cash_transactions
#
#  id                    :bigint           not null, primary key
#  description           :string           not null
#  comment               :text
#  date                  :date             not null
#  month                 :integer          not null
#  year                  :integer          not null
#  starting_price        :integer          not null
#  price                 :integer          not null
#  paid                  :boolean          default(FALSE)
#  cash_transaction_type :string
#  user_id               :bigint           not null
#  user_card_id          :bigint
#  user_bank_account_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :cash_transaction do
    description { "Meat" }
    comment { "Barbecue at Aunt's" }
    date { Date.new 2023, 12, 16 }
    month { date.month }
    year { date.year }
    price { 29.72 }

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    trait :different do
      description { "HotWheels" }
      comment { "Toy for brother-in-law" }
      date { Date.new 2024, 1, 16 }
      month { 1 }
      year { 2024 }
      price { 650 }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }
    end

    trait :random do
      description { Faker::Lorem.sentence }
      comment { [ Faker::Lorem.sentence, nil, nil, nil, nil ].sample }
      date { Faker::Date.between(from: 3.months.ago, to: Date.current) }
      price { Faker::Number.number(digits: rand(3..5)) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }
    end
  end
end
