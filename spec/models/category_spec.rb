# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  category_name :string           not null
#  built_in      :boolean          default(FALSE), not null
#  user_id       :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require 'rails_helper'

RSpec.describe Category, type: :model do
  let!(:category) { FactoryBot.create(:category, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(category).to be_valid
      end

      %i[category_name].each do |attribute|
        it_behaves_like 'validate_nil', :category, attribute
        it_behaves_like 'validate_blank', :category, attribute
      end

      it_behaves_like 'validate_uniqueness_combination', :category, :category_name, :user
    end

    context '( associations )' do
      %i[user].each do |model|
        it "belongs_to #{model}" do
          expect(category).to respond_to model
        end
      end

      %i[card_transactions money_transactions investments].each do |model|
        it "has_many #{model}" do
          expect(category).to respond_to model
        end
      end
    end
  end
end
