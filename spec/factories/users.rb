# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  unconfirmed_email      :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
FactoryBot.define do
  factory :user do
    first_name { 'John' }
    last_name { 'Doe' }
    email { 'john@example.com' }
    password { '123123' }
    password_confirmation { '123123' }
    confirmed_at { Date.current }

    trait :different do
      first_name { 'Jane' }
      email { 'jane@example.com' }
    end

    trait :random do
      first_name { Faker::Name.unique.first_name }
      email { Faker::Internet.unique.email }
    end

    # INVALID
    trait :with_invalid_email do
      email { 'not_an_email' }
    end

    trait :with_invalid_password do
      password { '1' }
    end

    trait :with_different_password_confirmation do
      password_confirmation { '123456' }
    end
  end
end
