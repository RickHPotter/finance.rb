# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :user
end

# == Schema Information
#
# Table name: subscriptions
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
