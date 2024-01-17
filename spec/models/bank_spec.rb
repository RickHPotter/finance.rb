# frozen_string_literal: true

# == Schema Information
#
# Table name: banks
#
#  id         :bigint           not null, primary key
#  bank_name  :string           not null
#  bank_code  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Bank, type: :model do
  let!(:bank) { FactoryBot.create(:bank, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(bank).to be_valid
      end

      %i[bank_name bank_code].each do |attribute|
        it_behaves_like 'validate_nil', :bank, attribute
        it_behaves_like 'validate_blank', :bank, attribute
      end

      it_behaves_like 'validate_uniqueness_combination', :bank, :bank_name, :bank_code
    end

    context '( associations )' do
      %i[cards user_bank_accounts].each do |model|
        it "has_many #{model}" do
          expect(bank).to respond_to model
        end
      end
    end
  end
end
