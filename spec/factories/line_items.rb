# frozen_string_literal: true

FactoryBot.define do
  factory :line_item do
    transactable { custom_create_polymorphic(%i[cash_transaction card_transaction]) }
    description { Faker::Commerce.product_name }
    price { transactable.price.negative? ? -10_00 : 10_00 }
    category { custom_create(:category, options: { user: transactable.user }) }

    trait :with_entity do
      entity { custom_create(:entity, options: { user: transactable.user }) }
    end

    trait :for_cash do
      transactable { custom_create(:cash_transaction) }
      price { 10_00 }
    end

    trait :for_card do
      transactable { custom_create(:card_transaction) }
      price { -10_00 }
    end
  end
end
