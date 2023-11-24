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
  let(:valid_attributes) do
    {
      first_name: 'John',
      last_name: 'Doe',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(valid_attributes)
      expect(user).to be_valid
    end

    it 'requires an email' do
      user = User.new(valid_attributes.merge(email: nil))
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a unique email' do
      User.create(valid_attributes)
      user = User.new(valid_attributes)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'requires a password' do
      user = User.new(valid_attributes.merge(password: nil))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'requires a minimum password length' do
      user = User.new(valid_attributes.merge(password: 'short'))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end
  end

  describe 'associations' do
    xit 'has many user cards' do
      # user = User.create(valid_attributes)
      # has_many :user_cards
      # has_many :card_transactions
      # has_many :categories
      # has_many :entities
    end
  end
end
