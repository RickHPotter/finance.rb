# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  ct_description     :string           not null
#  ct_comment         :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  installments_count :integer          default(0), not null
#  card_id            :integer          not null
#  user_id            :integer          not null
#
require 'rails_helper'

RSpec.describe CardTransaction, type: :model do
  let(:card_transaction) { FactoryBot.create(:card_transaction) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(card_transaction).to be_valid
    end

    %i[date ct_description price installments_count].each do |attribute|
      it_behaves_like 'validate_nil', :card_transaction, attribute
      it_behaves_like 'validate_blank', :card_transaction, attribute
    end
  end

  describe 'associations' do
    %i[user user_card category category2 entity].each do |model|
      it "belongs_to #{model}" do
        expect(card_transaction).to respond_to model
      end
    end

    %i[installments].each do |model|
      it "has_many #{model}" do
        expect(card_transaction).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'return a formatted date' do
      expect(card_transaction.month_year).to eq 'DEC <23>'
    end
  end
end
