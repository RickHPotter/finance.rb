# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :integer          not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require 'rails_helper'

RSpec.describe Investment, type: :model do
  let(:investment) { FactoryBot.create(:investment) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(investment).to be_valid
    end

    %i[price date].each do |attribute|
      it_behaves_like 'validate_nil', :investment, attribute
      it_behaves_like 'validate_blank', :investment, attribute
    end
  end

  describe 'associations' do
    %i[user user_bank_account category].each do |model|
      it "belongs_to #{model}" do
        expect(investment).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'return a formatted date' do
      expect(investment.month_year).to eq 'DEC <23>'
    end
  end
end
