# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                     :bigint           not null, primary key
#  mt_description         :string           not null
#  mt_comment             :text
#  date                   :date             not null
#  month                  :integer          not null
#  year                   :integer          not null
#  starting_price         :decimal(, )      not null
#  price                  :decimal(, )      not null
#  money_transaction_type :string
#  user_id                :bigint           not null
#  user_card_id           :bigint
#  user_bank_account_id   :bigint
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

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    trait :different do
      mt_description { 'HotWheels' }
      mt_comment { 'Toy for brother-in-law' }
      price { 6.50 }
      month { 1 }
      year { 2024 }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.today) }
      mt_description { Faker::Lorem.sentence }
      mt_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }
    end
  end
end
