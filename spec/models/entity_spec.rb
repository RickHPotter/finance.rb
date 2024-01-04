# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  entity_name :string           not null
#  user_id     :bigint           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require 'rails_helper'

RSpec.describe Entity, type: :model do
  let!(:entity) { FactoryBot.create(:entity) }

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
      it 'is valid with valid attributes' do
        expect(entity).to be_valid
      end

      %i[entity_name].each do |attribute|
        it_behaves_like 'validate_nil', :entity, attribute
        it_behaves_like 'validate_blank', :entity, attribute
      end

      it_behaves_like 'validate_uniqueness', :entity, :entity_name
    end

    context '( associations )' do
      %i[user].each do |model|
        it "belongs_to #{model}" do
          expect(entity).to respond_to model
        end
      end

      %i[card_transactions].each do |model|
        it "has_many #{model}" do
          expect(entity).to respond_to model
        end
      end
    end
  end
end
