# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id                   :bigint           not null, primary key
#  user_card_name       :string           not null
#  days_until_due_date  :integer          not null
#  current_due_date     :date             not null
#  current_closing_date :date             not null
#  min_spend            :decimal(, )      not null
#  credit_limit         :decimal(, )      not null
#  active               :boolean          not null
#  user_id              :bigint           not null
#  card_id              :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :user_card do
    user_card_name { "Azul" }
    days_until_due_date { 7 }
    current_closing_date { Date.current }
    current_due_date { current_closing_date - days_until_due_date }
    min_spend { 100.00 }
    credit_limit { 2000.00 }
    active { true }

    user { custom_create(:user) }
    card { custom_create(:card) }

    trait :different do
      user_card_name { "MyCard" }
      days_until_due_date { 9 }
      current_closing_date { Date.current - 2.months }

      user { different_custom_create(:user) }
      card { different_custom_create(:card) }
    end

    trait :random do
      user_card_name { "#{card.card_name} - #{user.first_name}" }
      days_until_due_date { rand(4..10) }
      current_closing_date { Date.new(rand(2023..2024), rand(1..12), rand(1..28)) }
      min_spend { [ 0.00, 100.00, 200.00 ].sample }
      credit_limit { Faker::Number.decimal(l_digits: rand(3..4)).ceil + 200.00 }
      active { true }

      user { random_custom_create(:user) }
      card { random_custom_create(:card) }
    end
  end
end
