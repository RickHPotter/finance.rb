# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :integer          not null, primary key
#  card_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :card do
    card_name { 'Azul' }

    # VALID
    trait :different do
      card_name { 'Nubank' }
    end

    trait :random do
      card_name { "#{Faker::Color.unique.color_name} #{%w[Bronze Silver Gold Platinum Premium Black].sample}" }
    end
  end
end
