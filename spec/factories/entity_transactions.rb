# frozen_string_literal: true

# == Schema Information
#
# Table name: entity_transactions
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  exchanges_count   :integer          default(0), not null
#  entity_id         :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
FactoryBot.define do
  factory :entity_transaction do
    is_payer { true }
    status { 'pending' }
    transactable { custom_create_polymorphic(%i[card_transaction money_transaction]) }
    entity { custom_create(:entity, reference: { user: transactable.user }) }
    price { transactable.price }
    exchanges_count { 1 }

    # TODO: should this be a trait like in card_transaction factory
    after(:build) do |entity_transaction, _evaluator|
      next unless entity_transaction.is_payer

      price = entity_transaction.price
      status = entity_transaction.status

      entity_transaction.exchange_attributes ||= []
      entity_transaction.exchanges_count.times do
        entity_transaction.exchange_attributes << {
          exchange_type: status == 'finished' ? :non_monetary : %i[monetary non_monetary].sample,
          price: [price, price / 2, price / 3].sample.round(2)
        }
      end
    end

    trait :different do
      is_payer { true }
      status { 'finished' }
      price { 0.01 }
      transactable { different_custom_create_polymorphic(%i[card_transaction money_transaction]) }
      entity { different_custom_create(:entity, reference: { user: transactable.user }) }
      exchanges_count { 2 }
    end

    trait :random do
      is_payer { Faker::Boolean.boolean }
      status { %w[pending finished].sample }
      price { is_payer ? (transactable.price / 2).round(2) : 0.00 }
      transactable { random_custom_create_polymorphic(%i[card_transaction money_transaction]) }
      entity { random_custom_create(:entity, reference: { user: transactable.user }) }
      exchanges_count { is_payer ? [*1..3].sample : 0 }
    end

    trait :transactable_card_transaction do
      transactable { random_custom_create(:card_transaction) }
    end
  end
end
