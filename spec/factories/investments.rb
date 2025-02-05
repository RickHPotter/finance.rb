# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  date                 :date             not null
#  description          :string
#  month                :integer          not null
#  price                :integer          not null
#  year                 :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cash_transaction_id  :bigint
#  user_bank_account_id :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_investments_on_cash_transaction_id   (cash_transaction_id)
#  index_investments_on_user_bank_account_id  (user_bank_account_id)
#  index_investments_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :investment do
    price { 1.12 }
    date { Date.new(2023, 12, 16) }

    user { custom_create(:user) }
    user_bank_account { custom_create(:user_bank_account, reference: { user: }) }

    trait :different do
      price { 0.52 }
      date { Date.new(2023, 11, 26) }

      user { different_custom_create(:user) }
      user_bank_account { different_custom_create(:user_bank_account, reference: { user: }) }
    end

    trait :random do
      price { Faker::Number.number(digits: rand(3..4)) }
      date { Faker::Date.between(from: 1.months.ago, to: Date.current) }

      user { random_custom_create(:user) }
      user_bank_account { random_custom_create(:user_bank_account, reference: { user: }) }
    end
  end
end
