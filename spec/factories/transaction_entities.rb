# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_entities
#
#  id                    :bigint           not null, primary key
#  is_payer              :boolean          default(FALSE), not null
#  status                :integer          default("pending"), not null
#  amount_to_be_returned :decimal(, )      not null
#  amount_returned       :decimal(, )      not null
#  transactable_type     :string           not null
#  transactable_id       :bigint           not null
#  entity_id             :bigint           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :transaction_entity do
    is_payer { true }
    status { 'pending' }
    amount_to_be_returned { 100.0 }
    amount_returned { 0.0 }
    transactable { custom_create_polymorphic models: %i[card_transaction money_transaction] }
    entity { custom_create model: :entity, reference: { user: transactable.user } }

    trait :different do
      is_payer { true }
      status { 'finished' }
      amount_to_be_returned { 0.01 }
      amount_returned { 0.01 }
      transactable { different_custom_create_polymorphic models: %i[card_transaction money_transaction] }
      entity { different_custom_create model: :entity, reference: { user: transactable.user } }
    end

    trait :random do
      is_payer { Faker::Boolean.boolean }
      status { %w[pending finished].sample }
      amount_to_be_returned { Faker::Number.decimal(l_digits: 2) }
      amount_returned { status == 'finished' ? amount_to_be_returned : 0.00 }
      transactable { random_custom_create_polymorphic models: %i[card_transaction money_transaction] }
      entity { random_custom_create model: :entity, reference: { user: transactable.user } }
    end
  end
end
