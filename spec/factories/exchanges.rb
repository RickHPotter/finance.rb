# frozen_string_literal: true

FactoryBot.define do
  factory :exchange do
    exchange_type { 0 }
    price { 999 }
    date { Date.new(2023, 12, 16) }
    month { 12 }
    year { 2023 }
    bound_type { :standalone }
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

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  bound_type            :string           default("standalone"), not null
#  date                  :datetime         not null
#  exchange_type         :integer          default("non_monetary"), not null
#  exchanges_count       :integer          default(0), not null
#  month                 :integer          not null
#  number                :integer          default(1), not null
#  price                 :integer          not null
#  starting_price        :integer          not null
#  year                  :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cash_transaction_id   :bigint           indexed
#  entity_transaction_id :bigint           not null, indexed
#
# Indexes
#
#  index_exchanges_on_cash_transaction_id    (cash_transaction_id)
#  index_exchanges_on_entity_transaction_id  (entity_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (entity_transaction_id => entity_transactions.id)
#
