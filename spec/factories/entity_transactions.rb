# frozen_string_literal: true

FactoryBot.define do
  factory :entity_transaction do
    is_payer { true }
    status { "pending" }
    transactable { custom_create_polymorphic(%i[card_transaction cash_transaction]) }
    entity { custom_create(:entity, reference: { user: transactable.user }) }
    price { transactable.price }
    exchanges_count { 1 }

    trait :different do
      is_payer { true }
      status { "finished" }
      price { 0o01 }
      transactable { different_custom_create_polymorphic(%i[card_transaction cash_transaction]) }
      entity { different_custom_create(:entity, reference: { user: transactable.user }) }
      exchanges_count { 2 }
    end

    trait :random do
      is_payer { Faker::Boolean.boolean }
      status { %w[pending finished].sample }
      price { is_payer ? (transactable.price / 2).round(2) : 0.00 }
      transactable { random_custom_create_polymorphic(%i[card_transaction cash_transaction]) }
      entity { random_custom_create(:entity, reference: { user: transactable.user }) }
      exchanges_count { is_payer ? [ *1..3 ].sample : 0 }
    end

    trait :transactable_card_transaction do
      transactable { random_custom_create(:card_transaction) }
    end
  end
end

# == Schema Information
#
# Table name: entity_transactions
#
#  id                :bigint           not null, primary key
#  exchanges_count   :integer          default(0), not null
#  is_payer          :boolean          default(FALSE), not null
#  price             :integer          default(0), not null
#  status            :integer          default("pending"), not null
#  transactable_type :string           not null, indexed => [entity_id, transactable_id], indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  entity_id         :bigint           not null, indexed => [transactable_type, transactable_id], indexed
#  transactable_id   :bigint           not null, indexed => [entity_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_entity_transactions_on_composite_key  (entity_id,transactable_type,transactable_id) UNIQUE
#  index_entity_transactions_on_entity_id      (entity_id)
#  index_entity_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (entity_id => entities.id)
#
