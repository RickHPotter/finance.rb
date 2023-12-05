# frozen_string_literal: true

# == Schema Information
#
# Table name: banks
#
#  id         :integer          not null, primary key
#  bank_name  :string           not null
#  bank_code  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Bank, type: :model do
  let(:bank) { FactoryBot.build(:bank) }

  describe 'valid validations' do
    it 'is valid with valid attributes' do
      expect(bank).to be_valid
    end
  end

  describe 'presence validations' do
    it_behaves_like 'validate_nil', :bank, :bank_name
    it_behaves_like 'validate_blank', :bank, :bank_code
  end

  describe 'uniqueness validations' do
    # TODO: implement
    # it_behaves_like 'validate_uniqueness_double', :bank, :bank_name, :bank_code
  end

  describe 'associations' do
    %i[cards user_bank_accounts].each do |model|
      it "has_many #{model}" do
        expect(bank).to respond_to model
      end
    end
  end
end
