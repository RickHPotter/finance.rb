# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    email { "john@example.com" }
    password { "123123" }
    password_confirmation { "123123" }
    confirmed_at { Date.current }

    trait :different do
      first_name { "Jane" }
      email { "jane@example.com" }
    end

    trait :random do
      first_name { Faker::Name.unique.first_name }
      email { Faker::Internet.unique.email }
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           indexed
#  confirmed_at           :datetime
#  email                  :string           default(""), not null, indexed
#  encrypted_password     :string           default(""), not null
#  first_name             :string           not null
#  last_name              :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           indexed
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
