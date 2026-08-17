# frozen_string_literal: true

FactoryBot.define do
  sequence(:friendship_user_email)   { |n| "friendship_user_#{n}@example.com" }
  sequence(:friendship_friend_email) { |n| "friendship_friend_#{n}@example.com" }

  factory :friendship do
    user   { create(:user, :random) }
    friend { create(:user, :random) }
    state  { "pending" }

    trait :accepted do
      state { "accepted" }
    end

    trait :blocked do
      state { "blocked" }
    end

    trait :rejected do
      state { "rejected" }
    end

    trait :removed do
      state { "removed" }
    end
  end
end

# == Schema Information
#
# Table name: friendships
# Database name: primary
#
#  id         :bigint           not null, primary key
#  policies   :jsonb            not null
#  state      :string           default("pending"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  friend_id  :bigint           not null, indexed
#  public_id  :string           not null, uniquely indexed
#  user_id    :bigint           not null, indexed
#
# Indexes
#
#  index_friendships_on_friend_id                  (friend_id)
#  index_friendships_on_public_id                  (public_id) UNIQUE
#  index_friendships_on_user_and_friend_canonical  (LEAST(user_id, friend_id), GREATEST(user_id, friend_id)) UNIQUE
#  index_friendships_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (friend_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
