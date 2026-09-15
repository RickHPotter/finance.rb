# frozen_string_literal: true

FactoryBot.define do
  factory :baby_name_decision do
    user
    baby_name
    choice { "later" }
  end
end

# == Schema Information
#
# Table name: baby_name_decisions
# Database name: primary
#
#  id           :bigint           not null, primary key
#  choice       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  baby_name_id :bigint           not null, indexed, uniquely indexed => [user_id]
#  user_id      :bigint           not null, indexed, uniquely indexed => [baby_name_id]
#
# Indexes
#
#  index_baby_name_decisions_on_baby_name_id              (baby_name_id)
#  index_baby_name_decisions_on_user_id                   (user_id)
#  index_baby_name_decisions_on_user_id_and_baby_name_id  (user_id,baby_name_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (baby_name_id => baby_names.id)
#  fk_rails_...  (user_id => users.id)
#
