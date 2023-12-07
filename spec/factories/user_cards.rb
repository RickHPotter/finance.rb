# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id             :integer          not null, primary key
#  user_card_name :string           not null
#  due_date_day   :integer          not null
#  min_spend      :decimal(, )      not null
#  credit_limit   :decimal(, )      not null
#  active         :boolean          not null
#  user_id        :integer          not null
#  card_id        :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :user_card do
    user_card_name { 'Azul' }
    due_date_day { 1 }
    min_spend { 100.00 }
    credit_limit { 2000.00 }
    active { true }

    association :user
    association :card

    # VALID
    trait :different do
      user_card_name { 'MyCard' }
      due_date_day { 16 }

      association :user, :different
      association :card, :different
    end

    trait :random do
      user_card_name { "#{card.card_name} - #{user.first_name}" }
      due_date_day { rand(1..31) }
      min_spend { [0.00, 100.00, 200.00].sample }
      credit_limit { Faker::Number.decimal(l_digits: rand(3..4)).ceil + 200.00 }
      active { true }

      association :user, :random
      association :card, :random
    end
  end
end
