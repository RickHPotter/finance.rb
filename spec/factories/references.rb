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
