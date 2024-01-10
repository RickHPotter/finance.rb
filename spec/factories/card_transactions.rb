# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                   :bigint           not null, primary key
#  ct_description       :string           not null
#  ct_comment           :text
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  installments_count   :integer          default(0), not null
#  user_id              :bigint           not null
#  user_card_id         :bigint           not null
#  category_id          :bigint           not null
#  category2_id         :bigint
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :card_transaction do
    date { Date.new 2023, 12, 16 }
    ct_description { 'La Plaza Paraty' }
    ct_comment { nil }
    price { 140.00 }
    month { 12 }
    year { 2023 }
    installments_count { 1 }

    association :user
    category { custom_create(:category, reference: { user: }) }
    user_card { custom_create(:user_card, reference: { user: }) }

    trait :different do
      ct_description { 'Sitpass' }
      ct_comment { 'Home -> Leve Supermarket' }
      price { 4.3 }
      month { 1 }
      year { 2024 }

      association :user, :different
      category { different_custom_create(:category, reference: { user: }) }
      user_card { different_custom_create(:user_card, reference: { user: }) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.today) }
      ct_description { Faker::Lorem.sentence }
      ct_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }
      installments_count { [1, 1, 1, 2, rand(1..10)].sample }

      association :user, :random
      category { random_custom_create(:category, reference: { user: }) }
      user_card { random_custom_create(:user_card, reference: { user: }) }
    end
  end
end
