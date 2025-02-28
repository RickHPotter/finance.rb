# frozen_string_literal: true

FactoryBot.define do
  factory :budget do
    month { Date.current.month }
    year { Date.current.year }
    budget_value { -10_000 }
    remaining_value { -10_000 }
    inclusive { false }
    user { custom_create(:user) }
  end
end

# == Schema Information
#
# Table name: budgets
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  budget_value    :integer          not null
#  inclusive       :boolean          default(TRUE), not null
#  month           :integer          not null
#  remaining_value :integer          not null
#  year            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null, indexed
#
# Indexes
#
#  index_budgets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
