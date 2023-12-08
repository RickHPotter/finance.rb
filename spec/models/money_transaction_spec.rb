# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                   :integer          not null, primary key
#  mt_description       :string           not null
#  mt_comment           :string
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require 'rails_helper'

RSpec.describe MoneyTransaction, type: :model do
  let(:money_transaction) { FactoryBot.create(:money_transaction) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(money_transaction).to be_valid
    end

    %i[mt_description date price].each do |attribute|
      it_behaves_like 'validate_nil', :money_transaction, attribute
      it_behaves_like 'validate_blank', :money_transaction, attribute
    end
  end

  describe 'associations' do
    %i[user user_bank_account category].each do |model|
      it "belongs_to #{model}" do
        expect(money_transaction).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'returns a formatted date' do
      expect(money_transaction.month_year).to eq 'DEC <23>'
    end
  end
end
