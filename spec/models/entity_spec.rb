# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :integer          not null, primary key
#  entity_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
require 'rails_helper'

RSpec.describe Entity, type: :model do
  let(:entity) { FactoryBot.build(:entity) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(entity).to be_valid
    end

    %i[entity_name].each do |attribute|
      it_behaves_like 'validate_nil', :entity, attribute
      it_behaves_like 'validate_blank', :entity, attribute
    end
  end

  describe 'uniqueness validations' do
    it_behaves_like 'validate_uniqueness', :entity, :entity_name
  end

  describe 'associations' do
    %i[user card_transactions].each do |model|
      it "has_many #{model}" do
        expect(entity).to respond_to model
      end
    end
  end
end
