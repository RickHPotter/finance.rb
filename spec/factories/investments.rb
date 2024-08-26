# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :bigint           not null
#  user_bank_account_id :bigint           not null
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :investment do
    price { 1.12 }
    date { Date.new(2023, 12, 16) }

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    trait :different do
      price { 0.52 }
      date { Date.new(2023, 11, 26) }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }
    end

    trait :random do
      price { Faker::Number.number(digits: rand(3..4)) }
      date { Faker::Date.between(from: 1.months.ago, to: Date.current) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }
    end
  end
end
