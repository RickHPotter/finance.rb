# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                          :bigint           not null, primary key
#  description                 :string           not null
#  comment                     :text
#  date                        :date             not null
#  month                       :integer          not null
#  year                        :integer          not null
#  starting_price              :integer          not null
#  price                       :integer          not null
#  card_installments_count     :integer          default(0), not null
#  user_id                     :bigint           not null
#  user_card_id                :bigint           not null
#  advance_cash_transaction_id :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :card_transaction do
    date { Date.new 2023, 12, 16 }
    description { "La Plaza Paraty" }
    comment { nil }
    price { 14_000 }
    month { (Date.new(date.year, date.month) + 1.month).month }
    year { (Date.new(date.year, date.month) + 1.month).year }

    user { custom_create(:user) }
    user_card { custom_create(:user_card, reference: { user: }) }

    card_installments { build_list(:card_installment, 1, price:) }
    category_transactions do
      build_list(:category_transaction, 1, :random, category: random_custom_create(:category, reference: { user: }), transactable: nil)
    end
    entity_transactions do
      price = price.to_i / 5
      build_list(:entity_transaction, 1, :random, is_payer: false, entity: random_custom_create(:entity, reference: { user: }), transactable: nil, price:)
    end

    trait :different do
      description { "Sitpass" }
      comment { "Home -> Leve Supermarket" }
      price { 4.3 }
      month { 1 }
      year { 2024 }

      user { different_custom_create(:user) }
      user_card { different_custom_create(:user_card, reference: { user: }) }

      card_installments do
        build_list(:card_installment, 2, price: (price / 2).round(2)) do |installment, i|
          installment.assign_attributes(number: i + 1)
        end
      end
      entity_transactions do
        price = price.to_i / 3
        build_list(:entity_transaction, 1, :random, is_payer: true, entity: random_custom_create(:entity, reference: { user: }), transactable: nil, price:)
      end
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.current) }
      description { Faker::Lorem.sentence }
      comment { [ Faker::Lorem.sentence, nil, nil, nil, nil ].sample }
      price { Faker::Number.number(digits: rand(3..5)) }

      user { random_custom_create(:user) }
      user_card { random_custom_create(:user_card, reference: { user: }) }

      card_installments do
        build_list(:card_installment, 3, price: (price / date.month).round(2)) do |installment, i|
          installment.assign_attributes(number: i + 1)
        end
      end
      entity_transactions do
        price = price.to_i / 3
        build_list(:entity_transaction, 1, :random, entity: random_custom_create(:entity, reference: { user: }), transactable: nil, price:)
      end
    end
  end
end
