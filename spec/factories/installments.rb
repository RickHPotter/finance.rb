# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                  :bigint           not null, primary key
#  starting_price      :integer          not null
#  price               :integer          not null
#  number              :integer          not null
#  month               :integer          not null
#  year                :integer          not null
#  installments_count  :integer          default(0), not null
#  card_transaction_id :bigint           not null
#  cash_transaction_id :bigint           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
FactoryBot.define do
  factory :installment do
    price { 999 }
    number { 1 }
    month { 12 }
    year { 2023 }

    trait :different do
      price { 9999 }
      month { 1 }
      year { 2024 }
    end

    trait :random do
      price { Faker::Number.number(digits: 5) }
    end
  end
end
