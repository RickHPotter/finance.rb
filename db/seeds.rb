# frozen_string_literal: true

require 'faker'

User.create!(first_name: 'John', last_name: 'Doe', email: 'john@user.com',
             password: '123123', password_confirmation: '123123')
User.create!(first_name: 'Jane', last_name: 'Doe', email: 'jane@user.com',
             password: '123123', password_confirmation: '123123')

20.times do
  Card.create!(card_name: Faker::Color.unique.color_name)
  Category.create!(description: Faker::Commerce.unique.department, user_id: User.all.sample.id)
  Entity.create!(entity_name: Faker::Company.unique.name, user_id: User.all.sample.id)
end

loop do
  UserCard.create(
    user_id: User.all.sample.id,
    card_id: Card.all.sample.id,
    # card_name: set_card_name callback will handle this
    due_date: rand(1..31),
    credit_limit: Faker::Number.decimal(l_digits: rand(3..4)).ceil + 200.00,
    min_spend: [0.00, 100.00, 200.00].sample
    # active: set_active callback will handle this
  )
  break if UserCard.all.count == 10
end

100.times do
  date = Faker::Date.between(from: 3.months.ago, to: Date.today)
  card_transaction = CardTransaction.create!(
    date:,
    description: Faker::Lorem.sentence,
    comment: [Faker::Lorem.sentence, nil].sample,
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

# TODO: Add Transactions
