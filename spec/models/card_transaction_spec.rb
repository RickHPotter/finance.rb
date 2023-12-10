# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :integer          not null
#  user_card_id       :integer          not null
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require 'rails_helper'

RSpec.describe CardTransaction, type: :model do
  let(:card_transaction) { FactoryBot.create(:card_transaction) }

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
      it 'is valid with valid attributes' do
        expect(card_transaction).to be_valid
      end

      %i[date ct_description price installments_count].each do |attribute|
        it_behaves_like 'validate_nil', :card_transaction, attribute
        it_behaves_like 'validate_blank', :card_transaction, attribute
      end
    end

    context '( associations )' do
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
  end

  describe '[ business logic ]' do
    context '( public methods )' do
      it 'returns a formatted date' do
        expect(card_transaction.month_year).to eq 'DEC <23>'
      end
    end
  end
end
