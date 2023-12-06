# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id                   :integer          not null, primary key
#  t_description        :string           not null
#  t_comment            :string
#  date                 :date             not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  month                :integer          not null
#  year                 :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_bank_account_id :integer          not null
#
FactoryBot.define do
  factory :transaction do
    t_description { 'Meat' }
    t_comment { 'Barbecue at Aunt\'s' }
    date { Date.new 2023, 12, 16 }
    price { 29.72 }
    month { 12 }
    year { 2023 }

    association :user
    category { user.categories.sample || FactoryBot.create(:category, user:) }
    user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, user:) }

    trait :different do
      t_description { 'HotWheels' }
      t_comment { 'Toy for brother-in-law' }
      price { 6.50 }
      month { 1 }
      year { 2024 }

      category { user.categories.sample || FactoryBot.create(:category, :different, user:) }
      user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, :different, user:) }
    end

    trait :random do
      date { Faker::Date.between(from: 3.months.ago, to: Date.today) }
      t_description { Faker::Lorem.sentence }
      t_comment { [Faker::Lorem.sentence, nil, nil, nil, nil].sample }
      price { Faker::Number.decimal(l_digits: rand(1..3)) }

      user { FactoryBot.create(:user, :random) }
      category { user.categories.sample || FactoryBot.create(:category, :random, user:) }
      user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, :random, user:) }
    end
  end
end
