# frozen_string_literal: true

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :integer          not null, primary key
#  agency_number  :integer
#  account_number :integer
#  user_id        :integer          not null
#  bank_id        :integer          not null
#  active         :boolean          default(TRUE), not null
#  balance        :decimal(, )      default(0.0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require 'rails_helper'

RSpec.describe UserBankAccount, type: :model do
  let(:user_bank_account) { FactoryBot.create(:user_bank_account) }

  describe 'valid validations' do
    it 'is valid with valid attributes' do
      expect(user_bank_account).to be_valid
    end
  end

  describe 'presence validations' do
    %i[balance user_id bank_id].each do |attribute|
      it_behaves_like 'validate_nil', :user_bank_account, attribute
      it_behaves_like 'validate_blank', :user_bank_account, attribute
    end
  end

  describe 'associations' do
    %i[user bank].each do |model|
      it "belongs_to #{model}" do
        expect(user_bank_account).to respond_to model
      end
    end

    %i[investments].each do |model|
      it "has_many #{model}" do
        expect(user_bank_account).to respond_to model
      end
    end
  end
end
