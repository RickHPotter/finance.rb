# frozen_string_literal: true

FactoryBot.define do
  factory :baby_name_process_state do
    user
    phase { "phase_1" }
    phase_completed { false }
  end
end

# == Schema Information
#
# Table name: baby_name_process_states
# Database name: primary
#
#  id              :bigint           not null, primary key
#  phase           :string           default("phase1"), not null
#  phase_completed :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_baby_name_process_states_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
