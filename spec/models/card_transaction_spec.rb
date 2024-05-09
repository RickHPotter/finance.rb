# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :bigint           not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require "rails_helper"

RSpec.describe CardTransaction, type: :model do
  let!(:user_card) { create(:user_card, :random, current_due_date: Date.new(2023, 12, 1)) }
  let!(:card_transaction) { create(:card_transaction, :random, user_card:, date: Date.new(2023, 11, 30)) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(card_transaction).to be_valid
      end

      %i[ct_description].each do |attribute|
        it_behaves_like "validate_nil", :card_transaction, attribute
        it_behaves_like "validate_blank", :card_transaction, attribute
      end
    end

    context "( associations )" do
      %i[user user_card].each do |model|
        it "belongs_to #{model}" do
          expect(card_transaction).to respond_to model
        end
      end

      %i[categories category_transactions entities entity_transactions installments].each do |model|
        it "has_many #{model}" do
          expect(card_transaction).to respond_to model
        end
      end
    end
  end

  # FIXME: move this to a PORO spec
  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns a formatted date" do
        expect(card_transaction.month_year).to eq "DEC <23>"
      end
    end
  end
end
