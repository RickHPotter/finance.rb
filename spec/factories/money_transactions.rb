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
#  paid                   :boolean          default(FALSE)
#  money_transaction_type :string
#  installments_count     :integer          default(0), not null
#  user_id                :bigint           not null
#  user_card_id           :bigint
#  user_bank_account_id   :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
FactoryBot.define do
  factory :money_transaction do
    mt_description { "Meat" }
    mt_comment { "Barbecue at Aunt's" }
    date { Date.new 2023, 12, 16 }
    month { 12 }
    year { 2023 }
    price { 29.72 }

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    installments { FactoryBot.build_list(:installment, 1, price:) }

    trait :different do
      mt_description { "HotWheels" }
      mt_comment { "Toy for brother-in-law" }
      date { Date.new 2024, 1, 16 }
      month { 1 }
      year { 2024 }
      price { 6.50 }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }
    end

    trait :random do
      mt_description { Faker::Lorem.sentence }
      mt_comment { [ Faker::Lorem.sentence, nil, nil, nil, nil ].sample }
      date { Faker::Date.between(from: 3.months.ago, to: Date.current) }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }
    end
  end
end
