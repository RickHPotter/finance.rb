# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  unconfirmed_email      :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
require "rails_helper"

RSpec.describe User, type: :model do
  let!(:subject) { build(:user) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[first_name last_name email password].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:email).case_insensitive }
      it { should validate_length_of(:password).is_at_least(6).is_at_most(22) }
      it { should validate_confirmation_of(:password) }
    end

    context "( associations )" do
      hm_models = %i[user_cards card_transactions user_bank_accounts cash_transactions categories entities]

      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns full_name" do
        expect(subject.full_name).to eq("John Doe")
      end
    end
  end
end
