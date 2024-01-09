FactoryBot.define do
  factory :exchange do
    exchange_type { 1 }
    amount_to_be_returned { "9.99" }
    amount_returned { "9.99" }
    transaction_entity { nil }
    money_transaction { nil }
  end
end
