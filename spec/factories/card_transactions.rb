# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  ct_description     :string           not null
#  ct_comment         :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  installments_count :integer          default(0), not null
#  card_id            :integer          not null
#  user_id            :integer          not null
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
    category { user.categories.sample || FactoryBot.create(:category, user:) }
    entity { user.entities.sample || FactoryBot.create(:entity, user:) }
    user_card { user.user_cards.sample || FactoryBot.create(:user_card, user:) }

    trait :different do
      ct_description { 'Sitpass' }
      ct_comment { 'Home -> Leve Supermarket' }
      price { 4.3 }
      month { 1 }
      year { 2024 }

      category { user.categories.sample || FactoryBot.create(:category, :different, user:) }
      entity { user.entities.sample || FactoryBot.create(:entity, :different, user:) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.today) }
      ct_description { Faker::Lorem.sentence }
      ct_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }
      installments_count { [1, 1, 1, 2, rand(1..10)].sample }

      user { FactoryBot.create(:user, :random) }
      category { user.categories.sample || FactoryBot.create(:category, :random, user:) }
      entity { user.entities.sample || FactoryBot.create(:entity, :random, user:) }
      user_card { user.user_cards.sample || FactoryBot.create(:user_card, :random, user:) }
    end
  end
end
