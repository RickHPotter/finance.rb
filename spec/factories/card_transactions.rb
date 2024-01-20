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
#  installments_count   :integer          default(1), not null
#  user_id              :bigint           not null
#  user_card_id         :bigint           not null
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

    user { custom_create(:user) }
    user_card { custom_create(:user_card, reference: { user: }) }

    trait :different do
      ct_description { 'Sitpass' }
      ct_comment { 'Home -> Leve Supermarket' }
      price { 4.3 }
      month { 1 }
      year { 2024 }

      user { different_custom_create(:user) }
      user_card { different_custom_create(:user_card, reference: { user: }) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.current) }
      ct_description { Faker::Lorem.sentence }
      ct_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }
      installments_count { [1, 1, 1, 2, rand(1..10)].sample }

      user { random_custom_create(:user) }
      user_card { random_custom_create(:user_card, reference: { user: }) }
    end

    trait :with_entity_transactions do
      entity_transaction_attributes do
        [{
          entity: random_custom_create(:entity, reference: { user: }),
          is_payer: true,
          status: 'pending',
          price: [price, price / 2, price / 3].sample.round(2),
          exchanges_count: 1,
          transactable: self,
          exchange_attributes: [{ exchange_type: :monetary, price: price / 3 }]
        }]
      end
    end

    trait :with_category_transactions do
      category_transaction_attributes do
        [{
          category: create(:category, :random, user:),
          transactable: self
        }]
      end
    end
  end
end
