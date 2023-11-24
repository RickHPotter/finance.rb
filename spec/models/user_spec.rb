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
  let(:jane) { FactoryBot.create(:user, :with_first_name_jane, :with_email_jane) }

  let(:without_first_name) { FactoryBot.build(:user, :without_first_name) }
  let(:without_last_name) { FactoryBot.build(:user, :without_last_name) }
  let(:without_email) { FactoryBot.build(:user, :without_email) }
  let(:without_password) { FactoryBot.build(:user, :without_password) }
  let(:with_different_password_confirmation) { FactoryBot.build(:user, :with_different_password_confirmation) }

  let(:with_recurring_email) { FactoryBot.build(:user, :with_email_jane) }
  let(:with_invalid_email) { FactoryBot.build(:user, :with_invalid_email) }
  let(:with_invalid_password) { FactoryBot.build(:user, :with_invalid_password) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(john).to be_valid
    end

    %i[first_name last_name email password].each do |attribute|
      it "is not valid with a nil #{attribute}" do
        user = public_send("without_#{attribute}")
        expect(user).to_not be_valid
        expect(user.errors[attribute]).to include("can't be blank")
      end
    end

    it 'requires a matching password confirmation' do
      expect(with_different_password_confirmation).to_not be_valid
      expect(with_different_password_confirmation.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it 'requires a unique email' do
      expect(jane).to be_valid
      expect(with_recurring_email).to_not be_valid
      expect(with_recurring_email.errors[:email]).to include('has already been taken')
    end

    it 'requires a valid email' do
      expect(with_invalid_email).to_not be_valid
      expect(with_invalid_email.errors[:email]).to include('is invalid')
    end

    it 'requires a minimum password length' do
      expect(with_invalid_password).to_not be_valid
      expect(with_invalid_password.errors[:password]).to include('is too short (minimum is 6 characters)')
    end
  end

  describe 'associations' do
    it 'has many user cards' do
      expect(john).to respond_to :user_cards
    end

    it 'has many card transactions' do
      expect(john).to respond_to :card_transactions
    end

    it 'has many categories' do
      expect(john).to respond_to :categories
    end

    it 'has many entities' do
      expect(john).to respond_to :entities
    end
  end

  describe 'public methods' do
    it 'returns full_name' do
      expect(john.full_name).to eq 'John Doe'
    end
  end
end
