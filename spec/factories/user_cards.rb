# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  card_id        :integer          not null
#  user_card_name :string           not null
#  due_date       :integer          not null
#  min_spend      :decimal(, )      not null
#  credit_limit   :decimal(, )      not null
#  active         :boolean          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :user_card do
    user_card_name { 'Azul' }
    due_date { 1 }
    min_spend { 100.00 }
    credit_limit { 2000.00 }
    active { true }

    association :user
    association :card

    # VALID
    trait :different do
      user_card_name { 'MyCard' }
      due_date { 16 }

      association :user, :different
      association :card, :different
    end

    trait :random do
      user_card_name { "#{Faker::Color.unique.color_name} #{%w[Bronze Silver Gold Platinum Premium Black].sample}" }
      due_date { rand(1..31) }
      min_spend { [0.00, 100.00, 200.00].sample }
      credit_limit { Faker::Number.decimal(l_digits: rand(3..4)).ceil + 200.00 }
      active { true }

      association :user, :random
      association :card, :random
    end
  end
end
