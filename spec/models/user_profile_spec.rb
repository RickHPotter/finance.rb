# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserProfile, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end

# == Schema Information
#
# Table name: user_profiles
# Database name: primary
#
#  id           :bigint           not null, primary key
#  display_name :string
#  first_name   :string
#  last_name    :string
#  locale       :string           default("en"), not null
#  timezone     :string           default("UTC"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_user_profiles_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
