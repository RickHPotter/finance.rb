# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_entities
#
#  id                    :bigint           not null, primary key
#  is_payer              :boolean          default(FALSE), not null
#  status                :integer          default(0), not null
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
    status { :pending }
    amount_to_be_returned { 100.0 }
    amount_returned { 0.0 }
    # TODO: this does not seem like the right thing
    association :user
    category { custom_create model: :category, reference: { user: } }
    association :transactable, factory: %i[card_transaction money_transaction], strategy: :create
    association :entity
  end
end
