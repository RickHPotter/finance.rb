# frozen_string_literal: true

FactoryBot.define do
  factory :investment_type do
    investment_type_name_fallback { "INVESTMENT" }
    investment_type_code { "investment" }

    trait :different do
      investment_type_name_fallback { "INVESTMENT2" }
      investment_type_code { "investment2" }
    end

    trait :random do
      investment_type_name_fallback { Faker::Lorem.sentence }
      investment_type_code { "#{Faker::Lorem.word}_#{Faker::Lorem.word}" }
    end
  end
end

# == Schema Information
#
# Table name: investment_types
# Database name: primary
#
#  id                            :bigint           not null, primary key
#  built_in                      :boolean          default(FALSE), not null, indexed
#  investment_type_code          :string           uniquely indexed
#  investment_type_name_fallback :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_investment_types_on_built_in              (built_in)
#  index_investment_types_on_investment_type_code  (investment_type_code) UNIQUE
#
