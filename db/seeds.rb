# frozen_string_literal: true

require "faker"

FactoryBot.create(:user, :random, first_name: "John", last_name: "Doe")
FactoryBot.create(:user, :random, first_name: "Jane", last_name: "Doe")
puts "Created Users.".green

FactoryBot.create_list(:bank, 3, :random)
puts "Created Banks.".green

Bank.find_each do |bank|
  FactoryBot.create(:card, :random, bank:)
end
puts "Created Cards.".green

User.find_each do |user|
  Bank.find_each do |bank|
    FactoryBot.create(:user_bank_account, :random, user:, bank:)
    puts "Created UserBankAccounts - BANK #{bank.bank_name} / #{user.full_name}.".blueish
  end

  Card.find_each do |card|
    FactoryBot.create(:user_card, :random, user:, card:)
    puts "Created UserCards - CARD #{card.card_name} / #{user.full_name}.".blueish
  end
end

User.find_each do |user|
  FactoryBot.create_list(:category, 3, :random, user:)
  puts "Created Categories - #{user.full_name}.".blueish

  FactoryBot.create_list(:entity, 3, :random, user:)
  puts "Created Entities - #{user.full_name}.".blueish
end

User.find_each do |user|
  user.user_cards.each do |user_card|
    [ Date.new(2023, 12, 16), Date.new(2024, 1, 16), Date.new(2024, 2, 16) ].each do |date|
      FactoryBot.create_list(:card_transaction, rand(3..6), :random, user:, user_card:, date:)
    end
    puts "Created CardTransactions - USERCARD #{user_card.user_card_name} / #{user.full_name}.".yellow
  end

  user.user_bank_accounts.each do |user_bank_account|
    FactoryBot.create_list(:cash_transaction, rand(2..4), :random, user:, user_bank_account:)
    puts "Created CashTransaction - USERBANKACCOUNT #{user_bank_account.agency_number}-#{user_bank_account.account_number} / #{user.full_name}.yellow."
  end

  user_bank_account = user.user_bank_accounts.sample
  (1..28).reverse_each { |index| FactoryBot.create(:investment, :random, user:, user_bank_account:, date: Date.current - index) }
  puts "Created Investments - #{user.full_name}.".yellow
end

puts "Done!".green
