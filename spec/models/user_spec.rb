# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:john) { FactoryBot.create(:user) }
  let(:with_different_password_confirmation) { FactoryBot.build(:user, :with_different_password_confirmation) }

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(john).to be_valid
    end

    %i[first_name last_name email password].each do |attribute|
      it_behaves_like 'validate_nil', :user, attribute
      it_behaves_like 'validate_blank', :user, attribute
    end
  end

  describe 'uniqueness validations' do
    it_behaves_like 'validate_uniqueness', :user, :email
  end

  describe 'lenght validations' do
    it_behaves_like 'validate_min_lenght', :user, :password, 6
    it_behaves_like 'validate_max_lenght', :user, :password, 22
  end

  describe 'invalid validations' do
    it_behaves_like 'validate_invalid', :user, :email
  end

  describe 'custom validations' do
    it 'requires a matching password confirmation' do
      expect(with_different_password_confirmation).to_not be_valid
      expect(with_different_password_confirmation.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'associations' do
    %i[user_cards card_transactions categories entities].each do |model|
      it "has_many #{model}" do
        expect(john).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'returns full_name' do
      expect(john.full_name).to eq 'John Doe'
    end
  end
end
