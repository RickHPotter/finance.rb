# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  starting_price        :decimal(, )      not null
#  price                 :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :exchange do
    exchange_type { 0 }
    price { 999 }
    entity_transaction { custom_create(:entity_transaction, options: { is_payer: true }) }

    trait :different do
      exchange_type { 1 }
      price { 999 }
      entity_transaction { different_custom_create(:entity_transaction, options: { is_payer: true }) }
    end

    trait :random do
      exchange_type { [ 0, 1 ].sample }
      price { Faker::Number.number(digits: 5) }
      entity_transaction { random_custom_create(:entity_transaction, options: { is_payer: true }) }
    end
  end
end
