# frozen_string_literal: true

FactoryBot.define do
  factory :reference do
    month { 3 }
    year { 2026 }
    reference_date { Date.new(2026, 3, 12) }
    reference_closing_date { Date.new(2026, 3, 5) }

    user_card { custom_create(:user_card) }
  end
end

# == Schema Information
#
# Table name: references
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, uniquely indexed => [user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null
#  year                   :integer          not null, uniquely indexed => [user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_card_id           :bigint           not null, uniquely indexed => [month, year], indexed
#
# Indexes
#
#  idx_references_user_card_month_year  (user_card_id,month,year) UNIQUE
#  index_references_on_user_card_id     (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_card_id => user_cards.id)
#
