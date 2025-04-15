# frozen_string_literal: true

FactoryBot.define do
  factory :budget do
    description { "#{I18n.l Date.current, format: :short} Some Categories / Some Entities / [ -10_000 ]" }
    month { Date.current.month }
    year { Date.current.year }
    value { -10_000 }
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
#  description     :string           not null
#  inclusive       :boolean          default(TRUE), not null
#  month           :integer          not null
#  remaining_value :integer          not null
#  starting_value  :integer          not null
#  value           :integer          not null
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
