# frozen_string_literal: true

require "rails_helper"

RSpec.describe BabyName, type: :model do
  let(:user) { create(:user) }

  it "returns active, unreviewed names in display order" do
    later_name = create(:baby_name, position: 2)
    first_name = create(:baby_name, position: 1)
    inactive_name = create(:baby_name, position: 3, active: false)
    create(:baby_name_decision, user:, baby_name: first_name)

    expect(described_class.active.unreviewed_by(user).in_display_order).to contain_exactly(later_name)
    expect(described_class.active).not_to include(inactive_name)
  end

  it "requires a unique name regardless of case" do
    create(:baby_name, name: "Theo")

    expect(build(:baby_name, name: "theo")).not_to be_valid
  end

  it "normalizes name to title case" do
    record = create(:baby_name, name: "nicholas")

    expect(record.name).to eq("Nicholas")
  end
end

# == Schema Information
#
# Table name: baby_names
# Database name: primary
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null, indexed => [position]
#  name       :string           not null
#  position   :integer          not null, indexed => [active]
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_baby_names_on_active_and_position  (active,position)
#  index_baby_names_on_lower_name           (lower((name)::text)) UNIQUE
#
