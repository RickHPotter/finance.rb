# frozen_string_literal: true

# == Schema Information
#
# Table name: category_transactions
#
#  id                :bigint           not null, primary key
#  category_id       :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
FactoryBot.define do
  factory :category_transaction do
    transactable { custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
    category { custom_create(:category, options: { user: transactable.user }) }

    trait :different do
      transactable { different_custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
      category { different_custom_create(:category, options: { user: transactable.user }) }
    end

    trait :random do
      transactable { random_custom_create_polymorphic(%i[card_transaction cash_transaction investment]) }
      category { random_custom_create(:category, options: { user: transactable.user }) }
    end
  end
end
