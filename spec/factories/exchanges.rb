# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  amount_to_be_returned :decimal(, )      not null
#  amount_returned       :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :exchange do
    exchange_type { 0 }
    amount_to_be_returned { '9.99' }
    amount_returned { '0.00' }
    entity_transaction { custom_create(:entity_transaction, options: { is_payer: true }) }

    trait :different do
      exchange_type { 1 }
      amount_to_be_returned { '9.99' }
      amount_returned { '9.99' }
      entity_transaction { different_custom_create(:entity_transaction, options: { is_payer: true }) }
    end

    trait :random do
      exchange_type { [0, 1].sample }
      amount_to_be_returned { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
      amount_returned { [0, amount_to_be_returned].sample }
      entity_transaction { random_custom_create(:entity_transaction, options: { is_payer: true }) }
    end
  end
end
