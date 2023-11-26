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
  end

  trait :different_card do
    card_name { 'Nubank' }
  end
end
