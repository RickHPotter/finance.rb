# frozen_string_literal: true

FactoryBot.define do
  factory :card do
    card_name { "AZUL" }
    bank { create(:bank) }

    trait :different do
      card_name { "NBNK" }
      bank { create(:bank, :different) }
    end

    trait :random do
      sequence(:card_name) do |n|
        "#{Faker::Color.color_name} #{%w[BRONZE SILVER GOLD PLATINUM PREMIUM BLACK].sample} #{n}".upcase
      end
      bank { create(:bank, :random) }
    end
  end
end

# == Schema Information
#
# Table name: cards
#
#  id         :bigint           not null, primary key
#  card_name  :string           not null, indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bank_id    :bigint           not null, indexed
#
# Indexes
#
#  index_cards_on_bank_id    (bank_id)
#  index_cards_on_card_name  (card_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id)
#
