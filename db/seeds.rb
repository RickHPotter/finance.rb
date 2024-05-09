# frozen_string_literal: true

require "faker"

FactoryBot.create(:user)
FactoryBot.create(:user, :different)
FactoryBot.create(:user, :random)
p "Created Users."

FactoryBot.create_list(:bank, 5, :random)
p "Created Banks."

Bank.find_each do |bank|
  FactoryBot.create(:card, :random, bank:)
end
p "Created Cards."

User.find_each do |user|
  Bank.find_each do |bank|
    FactoryBot.create(:user_bank_account, :random, user:, bank:)
    p "Created UserBankAccounts - BANK #{bank.bank_name} / #{user.full_name}."
  end

  Card.find_each do |card|
    FactoryBot.create(:user_card, :random, user:, card:)
    p "Created UserCards - CARD #{card.card_name} / #{user.full_name}."
  end
end

User.find_each do |user|
  FactoryBot.create_list(:category, 5, :random, user:)
  p "Created Categories - #{user.full_name}."

  FactoryBot.create_list(:entity, 5, :random, user:)
  p "Created Entities - #{user.full_name}."
end

User.find_each do |user|
  user.user_cards.each do |user_card|
    [ Date.new(2023, 12, 16), Date.new(2024, 1, 16), Date.new(2024, 2, 16) ].each do |date|
      FactoryBot.create_list(:card_transaction, rand(12..18), :random, user:, user_card:, date:)
    end
    p "Created CardTransactions - USERCARD #{user_card.user_card_name} / #{user.full_name}."
  end

  user.user_bank_accounts.each do |user_bank_account|
    FactoryBot.create_list(:money_transaction, rand(2..6), :random, user:, user_bank_account:)
    p "Created MoneyTransaction - USERBANKACCOUNT #{user_bank_account.agency_number}-#{user_bank_account.account_number} / #{user.full_name}."
  end

  user_bank_account = user.user_bank_accounts.sample
  (1..28).reverse_each { |index| FactoryBot.create(:investment, :random, user:, user_bank_account:, date: Date.current - index) }
  p "Created Investments - #{user.full_name}."
end

p "Done!"
