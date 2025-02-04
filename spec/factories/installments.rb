# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  number                  :integer          not null
#  date                    :date             not null
#  month                   :integer          not null
#  year                    :integer          not null
#  starting_price          :integer          not null
#  price                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  installment_type        :string           not null
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
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
