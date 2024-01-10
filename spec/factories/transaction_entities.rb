# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_entities
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  entity_id         :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
FactoryBot.define do
  factory :transaction_entity do
    is_payer { true }
    status { 'pending' }
    transactable { custom_create_polymorphic models: %i[card_transaction money_transaction] }
    entity { custom_create model: :entity, reference: { user: transactable.user } }
    price { transactable.price }

    trait :different do
      is_payer { true }
      status { 'finished' }
      price { 0.01 }
      transactable { different_custom_create_polymorphic models: %i[card_transaction money_transaction] }
      entity { different_custom_create model: :entity, reference: { user: transactable.user } }
    end

    trait :random do
      is_payer { Faker::Boolean.boolean }
      status { %w[pending finished].sample }
      transactable { random_custom_create_polymorphic models: %i[card_transaction money_transaction] }
      entity { random_custom_create model: :entity, reference: { user: transactable.user } }

      price { is_payer ? (transactable.price / 2).round(2) : 0.00 }
    end
  end
end
