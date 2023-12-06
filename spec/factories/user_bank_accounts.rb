# frozen_string_literal: true

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :integer          not null, primary key
#  agency_number  :integer
#  account_number :integer
#  user_id        :integer          not null
#  bank_id        :integer          not null
#  active         :boolean          default(TRUE), not null
#  balance        :decimal(, )      default(0.0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :user_bank_account do
    agency_number { '1324' }
    account_number { '123456' }
    balance { 393.92 }

    association :user
    association :bank

    trait :different do
      agency_number { '3422' }
      account_number { '564122' }
      balance { 0.00 }

      bank { FactoryBot.create(:bank, :different) }
    end

    trait :random do
      agency_number { Faker::Number.number(digits: 4) }
      account_number { Faker::Number.number(digits: 6) }
      balance { Faker::Number.decimal(l_digits: 2) }

      user { FactoryBot.create(:user, :random) }
      bank { FactoryBot.create(:bank, :random) }
    end
  end
end
