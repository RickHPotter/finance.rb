# frozen_string_literal: true

FactoryBot.define do
  factory :bank do
    bank_name { "ITAU" }
    bank_code { "479" }

    trait :different do
      bank_name { "NBNK" }
      bank_code { "001" }
    end

    trait :random do
      bank_name { Faker::Bank.name.split.sample }
      bank_code { Faker::Bank.unique.bsb_number }
    end
  end
end

# == Schema Information
#
# Table name: banks
#
#  id         :bigint           not null, primary key
#  bank_code  :integer          not null
#  bank_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
