# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :bigint           not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
FactoryBot.define do
  factory :card_transaction do
    date { Date.new 2023, 12, 16 }
    ct_description { "La Plaza Paraty" }
    ct_comment { nil }
    price { 140.00 }
    month { (Date.new(date.year, date.month) + 1.month).month }
    year { (Date.new(date.year, date.month) + 1.month).year }

    user { custom_create(:user) }
    user_card { custom_create(:user_card, reference: { user: }) }

    category_transactions { build_list(:category_transaction, 1, :random) }
    entity_transactions { build_list(:entity_transaction, 1, :random, is_payer: false) }
    installments { build_list(:installment, 1, :random, price:) }

    trait :different do
      ct_description { "Sitpass" }
      ct_comment { "Home -> Leve Supermarket" }
      price { 4.3 }
      month { 1 }
      year { 2024 }

      user { different_custom_create(:user) }
      user_card { different_custom_create(:user_card, reference: { user: }) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.current) }
      ct_description { Faker::Lorem.sentence }
      ct_comment { [ Faker::Lorem.sentence, nil, nil, nil, nil ].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }

      user { random_custom_create(:user) }
      user_card { random_custom_create(:user_card, reference: { user: }) }
    end
  end
end
