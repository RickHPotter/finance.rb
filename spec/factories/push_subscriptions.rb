# frozen_string_literal: true

FactoryBot.define do
  factory :push_subscription do
    endpoint { "https://example.com/push/#{SecureRandom.hex(4)}" }
    p256dh { SecureRandom.hex(8) }
    auth { SecureRandom.hex(4) }

    user { custom_create(:user) }
  end
end
