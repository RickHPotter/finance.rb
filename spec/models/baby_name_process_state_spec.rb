# frozen_string_literal: true

require "rails_helper"

RSpec.describe BabyNameProcessState, type: :model do
  let(:user) { create(:user) }

  it "enforces one process state per user" do
    create(:baby_name_process_state, user:)
    duplicate = build(:baby_name_process_state, user:)

    expect(duplicate).not_to be_valid
  end

  it "defaults to phase_1 and incomplete" do
    state = described_class.for(user)

    expect(state).to be_phase1
    expect(state.phase_completed).to be(false)
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
