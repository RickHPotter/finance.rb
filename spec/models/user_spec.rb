# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:subject) { build(:user) }

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
      hm_models = %i[card_transactions card_installments advance_cash_transactions
                     cash_transactions cash_installments
                     user_cards user_bank_accounts categories entities]

      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( callbacks )" do
      it "creates built_in categories on create" do
        subject.save
        built_in_categories = [ "CARD PAYMENT", "CARD ADVANCE", "CARD INSTALLMENT", "INVESTMENT", "EXCHANGE", "EXCHANGE RETURN" ]
        expect(subject.categories.built_in.pluck(:category_name)).to include(*built_in_categories)
      end
    end

    context "( public methods )" do
      it "returns full_name" do
        expect(subject.full_name).to eq("John Doe")
      end
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           indexed
#  confirmed_at           :datetime
#  email                  :string           default(""), not null, indexed
#  encrypted_password     :string           default(""), not null
#  first_name             :string           not null
#  last_name              :string           not null
#  locale                 :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           indexed
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
