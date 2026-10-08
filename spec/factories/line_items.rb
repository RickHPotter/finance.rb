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

# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  comment                    :text
#  description                :string           not null
#  friend_notification_intent :string
#  price                      :integer          default(0), not null
#  transactable_type          :string           not null, indexed => [transactable_id]
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  transactable_id            :bigint           not null, indexed => [transactable_type]
#
# Indexes
#
#  index_line_items_on_transactable_type_and_transactable_id  (transactable_type,transactable_id)
#
