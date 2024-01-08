# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :bigint           not null, primary key
#  card_name  :string           not null
#  bank_id    :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Card, type: :model do
  let!(:card) { FactoryBot.create(:card, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
      it 'is valid with valid attributes' do
        expect(card).to be_valid
      end

      %i[card_name].each do |attribute|
        it_behaves_like 'validate_nil', :card, attribute
        it_behaves_like 'validate_blank', :card, attribute
      end

      it_behaves_like 'validate_uniqueness', :card, :card_name
    end

    context '( associations )' do
      %i[user_cards].each do |model|
        it "has_many #{model}" do
          expect(card).to respond_to model
        end
      end
    end
  end
end
