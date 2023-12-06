# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id            :integer          not null, primary key
#  category_name :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer          not null
#
require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:category) { FactoryBot.create(:category) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(category).to be_valid
    end

    %i[category_name].each do |attribute|
      it_behaves_like 'validate_nil', :category, attribute
      it_behaves_like 'validate_blank', :category, attribute
    end
  end

  describe 'uniqueness validations' do
    it_behaves_like 'validate_uniqueness', :category, :category_name
  end

  describe 'associations' do
    %i[user].each do |model|
      it "belongs_to #{model}" do
        expect(category).to respond_to model
      end
    end

    %i[card_transactions transactions investments].each do |model|
      it "has_many #{model}" do
        expect(category).to respond_to model
      end
    end
  end
end
