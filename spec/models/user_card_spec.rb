# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  card_id        :integer          not null
#  user_card_name :string           not null
#  due_date       :integer          not null
#  min_spend      :decimal(, )      not null
#  credit_limit   :decimal(, )      not null
#  active         :boolean          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require 'rails_helper'

RSpec.describe UserCard, type: :model do
  let(:user_card) { FactoryBot.create(:user_card) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(user_card).to be_valid
    end

    # user_card_name and active callbacks test
    %i[due_date min_spend credit_limit].each do |attribute|
      it_behaves_like 'validate_nil', :user_card, attribute
      it_behaves_like 'validate_blank', :user_card, attribute
    end
  end

  describe 'uniqueness validations', focus: true do
    it_behaves_like 'validate_uniqueness_combination', :user_card, :user_card_name, :user
  end

  describe 'length validations' do
    message = 'must be between 1 and 31'
    it_behaves_like 'validate_min_number', :user_card, :due_date, 1, message
    it_behaves_like 'validate_max_number', :user_card, :due_date, 31, message
  end

  describe 'associations' do
    %i[user card card_transactions].each do |model|
      it "has_many #{model}" do
        expect(user_card).to respond_to model
      end
    end
  end
end
