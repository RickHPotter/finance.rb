# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id                   :integer          not null, primary key
#  t_description        :string           not null
#  t_comment            :string
#  date                 :date             not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  month                :integer          not null
#  year                 :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_bank_account_id :integer          not null
#
require 'rails_helper'

RSpec.describe Transaction, type: :model do
  let(:transaction) { FactoryBot.create(:transaction) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(transaction).to be_valid
    end

    # FIXME: why does category_id throw an error?
    %i[t_description date price user_id user_bank_account_id].each do |attribute|
      it_behaves_like 'validate_nil', :transaction, attribute
      it_behaves_like 'validate_blank', :transaction, attribute
    end
  end

  describe 'associations' do
    %i[user user_bank_account category].each do |model|
      it "belongs_to #{model}" do
        expect(transaction).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'return a formatted date' do
      expect(transaction.month_year).to eq 'DEC <23>'
    end
  end
end
