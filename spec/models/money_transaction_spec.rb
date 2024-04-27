# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                     :bigint           not null, primary key
#  mt_description         :string           not null
#  mt_comment             :text
#  date                   :date             not null
#  month                  :integer          not null
#  year                   :integer          not null
#  starting_price         :decimal(, )      not null
#  price                  :decimal(, )      not null
#  paid                   :boolean          default(FALSE)
#  money_transaction_type :string
#  user_id                :bigint           not null
#  user_card_id           :bigint
#  user_bank_account_id   :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
require "rails_helper"

RSpec.describe MoneyTransaction, type: :model do
  let(:money_transaction) { build(:money_transaction, :random, date: Date.new(2023, 12, 16)) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(money_transaction).to be_valid
      end

      %i[mt_description price].each do |attribute|
        it_behaves_like "validate_nil", :money_transaction, attribute
        it_behaves_like "validate_blank", :money_transaction, attribute
      end
    end

    context "( associations )" do
      %i[user user_bank_account].each do |model|
        it "belongs_to #{model}" do
          expect(money_transaction).to respond_to model
        end
      end

      %i[categories].each do |model|
        it "has_many #{model}" do
          expect(money_transaction).to respond_to model
        end
      end
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns a formatted date" do
        expect(money_transaction.month_year).to eq "DEC <23>"
      end
    end
  end
end
