# frozen_string_literal: true

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

# == Schema Information
#
# Table name: category_transactions
#
#  id                :bigint           not null, primary key
#  transactable_type :string           not null, uniquely indexed => [category_id, transactable_id], indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  category_id       :bigint           not null, indexed, uniquely indexed => [transactable_type, transactable_id]
#  transactable_id   :bigint           not null, uniquely indexed => [category_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_category_transactions_on_category_id    (category_id)
#  index_category_transactions_on_composite_key  (category_id,transactable_type,transactable_id) UNIQUE
#  index_category_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
