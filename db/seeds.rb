# frozen_string_literal: true

require 'faker'

FactoryBot.create(:user)
FactoryBot.create(:user, :different)
FactoryBot.create(:user, :random)

# p 'Creating Banks...'

p 'Creating Cards...'
FactoryBot.create_list(:card, 15, :random)

p 'Creating Categories and Entities...'
User.all.each do |user|
  FactoryBot.create_list(:category, 5, :random, user:)
  FactoryBot.create_list(:entity, 5, :random, user:)
end

p 'Creating UserCards...'
loop do
  FactoryBot.create(:user_card, :random, user: User.all.sample, card: Card.all.sample)
  break if UserCard.all.count == 15
rescue ActiveRecord::RecordInvalid
  next
end

# p 'Creating UserBankAccounts...'

p 'Creating CardTransactions...'
User.all.each do |user|
  FactoryBot.create_list(:card_transaction, 40, :random, user:)
end

# p 'Creating MoneyTransactions...'
# p 'Creating Investments...'
# p 'Creating Exchanges...'

p 'Done!'
