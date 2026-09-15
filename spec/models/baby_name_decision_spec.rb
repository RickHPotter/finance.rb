# frozen_string_literal: true

require "rails_helper"

RSpec.describe BabyNameDecision, type: :model do
  it "allows one valid choice per user and name" do
    decision = create(:baby_name_decision, choice: "accepted")
    duplicate = build(:baby_name_decision, user: decision.user, baby_name: decision.baby_name, choice: "rejected")

    expect(decision).to be_accepted
    expect(duplicate).not_to be_valid
  end

  it "rejects an unknown choice" do
    expect(build(:baby_name_decision, choice: "maybe")).not_to be_valid
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
