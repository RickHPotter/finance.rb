# frozen_string_literal: true

FactoryBot.define do
  factory :cash_transaction do
    description { "MEAT" }
    comment { "Barbecue at Aunt's" }
    date { Date.new 2023, 12, 16 }
    month { date.month }
    year { date.year }
    price { 29.72 }

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    cash_installments { build_list(:cash_installment, 1, price:, number: 1) }

    trait :different do
      description { "HOTWHEELS" }
      comment { "Toy for brother-in-law" }
      date { Date.new 2024, 1, 16 }
      month { 1 }
      year { 2024 }
      price { 650 }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }

      cash_installments do
        build_list(:cash_installment, 2, price: price / 2) do |installment, i|
          installment.assign_attributes(number: i + 1)
        end
      end
    end

    trait :random do
      description { Faker::Lorem.sentence }
      comment { [ Faker::Lorem.sentence, nil, nil, nil, nil ].sample }
      date { Faker::Date.between(from: 3.months.ago, to: Time.zone.today) }
      price { Faker::Number.number(digits: rand(3..5)) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }

      cash_installments do
        build_list(:cash_installment, 3, price: price / date.month) do |installment, i|
          installment.assign_attributes(number: i + 1)
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: cash_transactions
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  cash_installments_count     :integer          default(0), not null
#  cash_transaction_type       :string
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null
#  reference_transactable_type :string           indexed => [reference_transactable_id], uniquely indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type], uniquely indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_investment_type_id       (investment_type_id)
#  index_cash_transactions_on_reference_transactable   (reference_transactable_type,reference_transactable_id)
#  index_cash_transactions_on_subscription_id          (subscription_id)
#  index_cash_transactions_on_user_bank_account_id     (user_bank_account_id)
#  index_cash_transactions_on_user_card_id             (user_card_id)
#  index_cash_transactions_on_user_id                  (user_id)
#  index_reference_transactable_on_cash_composite_key  (reference_transactable_type,reference_transactable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
