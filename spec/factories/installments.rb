# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :date             not null
#  installment_type        :string           not null
#  month                   :integer          not null
#  number                  :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#
# Indexes
#
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
FactoryBot.define do
  factory :card_installment, class: "CardInstallment" do
    price { 999 }
    installment_type { "CardInstallment" }

    trait :random do
      price { Faker::Number.number(digits: 5) }
    end
  end

  factory :cash_installment, class: "CashInstallment" do
    price { 999 }
    installment_type { "CashInstallment" }

    trait :random do
      price { Faker::Number.number(digits: 5) }
    end
  end
end
