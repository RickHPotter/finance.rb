# frozen_string_literal: true

FactoryBot.define do
  factory :baby_name do
    sequence(:name) { |number| "Name #{number}" }
    sequence(:position)
    active { true }
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
