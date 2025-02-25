# frozen_string_literal: true

FactoryBot.define do
  factory :user_card do
    user_card_name { "AZUL" }
    days_until_due_date { 7 }
    current_closing_date { Date.current }
    current_due_date { current_closing_date - days_until_due_date }
    min_spend { 10_000 }
    credit_limit { 200_000 }
    active { true }

    user { custom_create(:user) }
    card { custom_create(:card) }

    trait :different do
      user_card_name { "CLICK" }
      days_until_due_date { 9 }
      current_closing_date { Date.current - 2.months }

      user { different_custom_create(:user) }
      card { different_custom_create(:card) }
    end

    trait :random do
      user_card_name { "#{card.card_name} - #{user.first_name} #{rand(1000)}" }
      days_until_due_date { rand(4..10) }
      current_closing_date { Date.new(Date.current.year, Date.current.month, rand(1..28)) }
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
#  current_closing_date    :date             not null
#  current_due_date        :date             not null
#  days_until_due_date     :integer          not null
#  min_spend               :integer          not null
#  user_card_name          :string           not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_id                 :bigint           not null, indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_user_cards_on_card_id         (card_id)
#  index_user_cards_on_user_card_name  (user_card_name) UNIQUE
#  index_user_cards_on_user_id         (user_id)
#
