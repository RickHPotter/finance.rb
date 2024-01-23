# frozen_string_literal: true

require 'faker'

p 'Creating Users...'
FactoryBot.create(:user)
FactoryBot.create(:user, :different)
FactoryBot.create(:user, :random)

p 'Creating Banks...'
FactoryBot.create_list(:bank, 5, :random)

Bank.all.each do |bank|
  p "BANK #{bank.bank_name} - Creating UserBankAccounts..."
  FactoryBot.create_list(:user_bank_account, 3, :random, user: User.all.sample, bank:)

  p "BANK #{bank.bank_name} - Creating Cards..."
  FactoryBot.create_list(:card, 3, :random, bank:)
end

User.all.each do |user|
  p "Creating #{user.first_name} UserCards..."
  Card.all.each do |card|
    FactoryBot.create(:user_card, :random, user:, card:)
  end

  p "Creating #{user.first_name} Categories and Entities..."
  FactoryBot.create_list(:category, 5, :random, user:)
  FactoryBot.create_list(:entity, 5, :random, user:)

  p "Creating #{user.first_name} CardTransactions..."
  FactoryBot.create_list(:card_transaction, 40, :random, user:)

  p "Creating #{user.first_name} MoneyTransactions..."
  FactoryBot.create_list(:money_transaction, 10, :random, user:)

  p "Creating #{user.first_name} Investments..."
  (1..28).reverse_each do |index|
    FactoryBot.create(:investment, :random, user:, date: Date.current - index)
  end

  # p 'Creating EntityTransactions...' do
  ### p 'Creating Exchanges...'
  # end
end

p 'Done!'
