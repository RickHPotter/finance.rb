# frozen_string_literal: true

FactoryBot.define do
  factory :reference do
    month { 3 }
    year { 2026 }
    reference_date { Date.new(2026, 3, 12) }
    reference_closing_date { Date.new(2026, 3, 5) }

    user_card { custom_create(:user_card) }
    context { user_card.user.main_context }
  end
end

# == Schema Information
#
# Table name: references
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, uniquely indexed => [context_id, user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null, uniquely indexed => [context_id, user_card_id]
#  year                   :integer          not null, uniquely indexed => [context_id, user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  context_id             :bigint           not null, uniquely indexed => [user_card_id, month, year], uniquely indexed => [user_card_id, reference_date], indexed
#  user_card_id           :bigint           not null, uniquely indexed => [context_id, month, year], uniquely indexed => [context_id, reference_date], indexed
#
# Indexes
#
#  idx_references_context_user_card_month_year      (context_id,user_card_id,month,year) UNIQUE
#  idx_references_context_user_card_reference_date  (context_id,user_card_id,reference_date) UNIQUE
#  index_references_on_context_id                   (context_id)
#  index_references_on_user_card_id                 (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#
