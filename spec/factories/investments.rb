# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :integer          not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :investment do
    price { 1.12 }
    date { Date.new(2023, 12, 16) }

    association :user
    category { user.categories.sample || FactoryBot.create(:category, user:) }
    user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, user:) }

    trait :different do
      price { 0.52 }
      date { Date.new(2023, 11, 26) }

      association :user, :different
      category { user.categories.sample || FactoryBot.create(:category, :different, user:) }
      user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, :different, user:) }
    end

    trait :random do
      price { Faker::Number.decimal(l_digits: 2) }
      date { Faker::Date.between(from: 1.months.ago, to: Date.today) }

      association :user, :random
      category { user.categories.sample || FactoryBot.create(:category, :random, user:) }
      user_bank_account { user.user_bank_accounts.sample || FactoryBot.create(:user_bank_account, :random, user:) }
    end
  end
end
