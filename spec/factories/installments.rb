# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                   :bigint           not null, primary key
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  number               :integer          not null
#  month                :integer          not null
#  year                 :integer          not null
#  installments_count   :integer          default(0), not null
#  card_transaction_id  :bigint           not null
#  money_transaction_id :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :installment do
    price { "9.99" }
    number { 1 }
    month { 12 }
    year { 2023 }

    trait :different do
      price { "99.99" }
      month { 1 }
      year { 2024 }
    end

    trait :random do
      price { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    end
  end
end
