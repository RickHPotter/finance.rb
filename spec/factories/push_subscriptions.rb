# frozen_string_literal: true

FactoryBot.define do
  factory :push_subscription do
    endpoint { "https://example.com/push/#{SecureRandom.hex(4)}" }
    p256dh { SecureRandom.hex(8) }
    auth { SecureRandom.hex(4) }

    user { custom_create(:user) }
  end
end

# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id         :bigint           not null, primary key
#  auth       :text
#  endpoint   :text
#  p256dh     :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null, indexed
#
# Indexes
#
#  index_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
