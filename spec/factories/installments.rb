# frozen_string_literal: true

FactoryBot.define do
  factory :installment do
    price { '9.99' }
    number { 1 }
    paid { false }
  end
end
