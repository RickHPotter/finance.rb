# frozen_string_literal: true

require 'faker'

FactoryBot.create(:user)
FactoryBot.create(:user, :different)
FactoryBot.create(:user, :random)

p 'Creating Cards, Categories and Entities...'
FactoryBot.create_list(:card, 15, :random)
FactoryBot.create_list(:category, 10, :random, user_id: User.all.sample.id)
FactoryBot.create_list(:entity, 10, :random, user_id: User.all.sample.id)

p 'Creating UserCards...'
loop do
  FactoryBot.create(:user_card, :random, user: User.all.sample, card: Card.all.sample)
  break if UserCard.all.count == 15
rescue ActiveRecord::RecordInvalid
  next
end

p 'Creating CardTransactions...'
# @TODO: Apply FactoryBot
100.times do
  date = Faker::Date.between(from: 3.months.ago, to: Date.today)
  card_transaction = CardTransaction.create!(
    date:,
    ct_description: Faker::Lorem.sentence,
    ct_comment: [Faker::Lorem.sentence, nil].sample,
    category_id: Category.all.sample.id,
    entity_id: Entity.all.sample.id,
    # starting_price: set_starting_price callback will handle this
    price: Faker::Number.decimal(l_digits: rand(1..3)),
    month: date.month,
    year: date.year,
    installments_count: [1, 1, 1, 2, rand(1..10)].sample,
    card_id: UserCard.all.sample.id,
    user_id: User.all.sample.id
  )

  card_transaction.create_default_installments
end

p 'Done!'
