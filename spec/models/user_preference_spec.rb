# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPreference, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end

# == Schema Information
#
# Table name: user_preferences
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  date_time_presentation :string           default("relative"), not null
#  landing_page           :string           default("dashboard"), not null
#  page_density           :string           default("comfortable"), not null
#  theme                  :string           default("system"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  active_context_id      :integer
#  default_account_id     :integer
#  default_card_id        :integer
#  user_id                :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_user_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
