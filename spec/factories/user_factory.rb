# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { 'John' }
    last_name { 'Doe' }
    email { 'john@example.com' }
    password { '123123' }
    password_confirmation { '123123' }
  end

  # VALID
  trait :with_first_name_jane do
    first_name { 'Jane' }
  end

  trait :with_email_jane do
    email { 'jane@example.com' }
  end

  # INVALID
  trait :without_first_name do
    first_name { nil }
  end

  trait :without_last_name do
    last_name { nil }
  end

  trait :without_email do
    email { nil }
  end

  trait :without_password do
    password { nil }
  end

  trait :with_different_password_confirmation do
    password_confirmation { '123456' }
  end

  trait :with_invalid_email do
    email { 'not_an_email' }
  end

  trait :with_invalid_password do
    password { '1' }
  end
end
