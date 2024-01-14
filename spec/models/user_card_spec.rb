# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id                   :bigint           not null, primary key
#  user_card_name       :string           not null
#  days_until_due_date  :integer          not null
#  current_due_date     :date             not null
#  current_closing_date :date             not null
#  min_spend            :decimal(, )      not null
#  credit_limit         :decimal(, )      not null
#  active               :boolean          not null
#  user_id              :bigint           not null
#  card_id              :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require 'rails_helper'

RSpec.describe UserCard, type: :model do
  let!(:user_card) { FactoryBot.create(:user_card, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(user_card).to be_valid
      end

      %i[current_due_date days_until_due_date min_spend credit_limit].each do |attribute|
        it_behaves_like 'validate_nil', :user_card, attribute
        it_behaves_like 'validate_blank', :user_card, attribute
      end
    end

    it_behaves_like 'validate_uniqueness_combination', :user_card, :user_card_name, :user

    context '( associations )' do
      %i[user card].each do |model|
        it "belongs_to #{model}" do
          expect(user_card).to respond_to model
        end
      end

      %i[card_transactions].each do |model|
        it "has_many #{model}" do
          expect(user_card).to respond_to model
        end
      end
    end
  end

  describe '[ business logic ]' do
    context '( callbacks )' do
      it 'assigns the correct current_closing_date given past current_due_date' do
        user_card.update(current_closing_date: nil,
                         current_due_date: Date.current.beginning_of_year - 1.year,
                         days_until_due_date: 7)
        expect(user_card.current_closing_date).to eq(user_card.current_due_date - 7.days)
      end

      it 'assigns the correct current_closing_date given future current_due_date' do
        user_card.update(current_closing_date: nil,
                         current_due_date: Date.current.beginning_of_year + 1.year,
                         days_until_due_date: 7)
        expect(user_card.current_closing_date).to eq(user_card.current_due_date - 7.days)
      end
    end
  end
end
