# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :integer          not null, primary key
#  card_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bank_id    :integer
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
      card_name { "#{Faker::Color.unique.color_name} #{%w[Bronze Silver Gold Platinum Premium Black].sample}" }
      bank { FactoryBot.create(:bank, :random) }
    end
  end
end
