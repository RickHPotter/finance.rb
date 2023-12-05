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
require 'rails_helper'

RSpec.describe Card, type: :model do
  let(:card) { FactoryBot.create(:card) }

  describe 'valid validations' do
    it 'is valid with valid attributes' do
      expect(card).to be_valid
    end
  end

  describe 'presence validations' do
    it_behaves_like 'validate_nil', :card, :card_name
    it_behaves_like 'validate_blank', :card, :card_name
  end

  describe 'uniqueness validations' do
    it_behaves_like 'validate_uniqueness', :card, :card_name
  end

  describe 'associations' do
    it { expect(card).to respond_to(:user_cards) }
  end
end
