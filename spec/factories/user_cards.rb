# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id           :integer          not null, primary key
#  user_id      :integer          not null
#  card_id      :integer          not null
#  card_name    :string           not null
#  due_date     :integer          not null
#  min_spend    :decimal(, )      not null
#  credit_limit :decimal(, )      not null
#  active       :boolean          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :user_card do
    card_name { 'Azul' }
    due_date { 1 }
    min_spend { 100.00 }
    credit_limit { 2000.00 }
    active { true }

    association :user
    association :card
  end

  trait :different_user_card do
    card_name { 'Nubank' }
    due_date { 2 }
    min_spend { 200.00 }
    credit_limit { 3000.00 }
    active { true }

    association :user
    association :card
  end

  trait :user_card_card_name_scope_user do
    different_user_card
    card_name { 'Nubank' }
    after(:build) do |user_card|
      user_card.user = FactoryBot.create(:user, email: "#{Time.now.to_i}@email.com")
    end

    after(:create) do |user_card|
      user_card.user.save
      user_card.card.save
    end
  end
end
