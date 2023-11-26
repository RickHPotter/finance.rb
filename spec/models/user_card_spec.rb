# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id           :integer          not null, primary key
#  user_id      :integer          not null
#  card_id      :integer          not null
#  card_name    :string           not null
#  due_date     :integer          not null
#  min_spend    :decimal(, )      not null
#  credit_limit :decimal(, )      not null
#  active       :boolean          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require 'rails_helper'

RSpec.describe UserCard, type: :model do
  let(:azul) { FactoryBot.create(:user_card) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(azul).to be_valid
    end

    # card_name and active callbacks test
    %i[due_date min_spend credit_limit].each do |attribute|
      it_behaves_like 'validate_nil', :user_card, attribute
      it_behaves_like 'validate_blank', :user_card, attribute
    end
  end

  describe 'uniqueness validations' do
    it_behaves_like 'validate_uniqueness_scope', :user_card, :card_name, :user
  end

  describe 'lenght validations' do
    it_behaves_like 'validate_min_number', :user_card, :due_date, 1
    it_behaves_like 'validate_max_number', :user_card, :due_date, 31
  end

  describe 'custom validations' do
    it 'requires a matching password confirmation' do
      expect(with_different_password_confirmation).to_not be_valid
      expect(with_different_password_confirmation.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'associations' do
    %i[user card card_transactions].each do |model|
      it "has_many #{model}" do
        expect(azul).to respond_to model
      end
    end
  end
end
