# frozen_string_literal: true

FactoryBot.define do
  factory :user_card do
    user_card_name { "AZUL" }
    days_until_due_date { 7 }
    due_date_day { 6 }
    min_spend { 10_000 }
    credit_limit { 200_000 }
    active { true }

    user { custom_create(:user) }
    card { custom_create(:card) }

    trait :different do
      user_card_name { "CLICK" }
      days_until_due_date { 10 }
      due_date_day { 7 }

      user { different_custom_create(:user) }
      card { different_custom_create(:card) }
    end

    trait :random do
      user_card_name { "#{card.card_name} - #{user.first_name} #{rand(1000)}" }
      days_until_due_date { rand(4..10) }
      due_date_day { rand(1..9) }
      min_spend { [ 0o00, 10_000, 20_000 ].sample }
      credit_limit { Faker::Number.number(digits: rand(6..7)) + 20_000 }
      active { true }

      user { random_custom_create(:user) }
      card { random_custom_create(:card) }
    end
  end
end

# == Schema Information
#
# Table name: user_cards
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  credit_limit            :integer          not null
#  days_until_due_date     :integer          not null
#  due_date_day            :integer          default(1), not null
#  min_spend               :integer          not null
#  user_card_name          :string           not null, indexed => [user_id, card_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_id                 :bigint           not null, indexed, indexed => [user_id, user_card_name]
#  user_id                 :bigint           not null, indexed => [card_id, user_card_name], indexed
#
# Indexes
#
#  index_user_cards_on_card_id           (card_id)
#  index_user_cards_on_on_composite_key  (user_id,card_id,user_card_name) UNIQUE
#  index_user_cards_on_user_id           (user_id)
#
