# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :integer          not null, primary key
#  card_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bank_id    :integer          not null
#
FactoryBot.define do
  factory :card do
    card_name { 'Azul' }
    bank { FactoryBot.create(:bank) }

    trait :different do
      card_name { 'Nubank' }
      bank { FactoryBot.create(:bank, :different) }
    end

    trait :random do
      sequence(:card_name) do |n|
        "#{Faker::Color.color_name} #{%w[Bronze Silver Gold Platinum Premium Black].sample} #{n}"
      end
      bank { FactoryBot.create(:bank, :random) }
    end
  end
end
