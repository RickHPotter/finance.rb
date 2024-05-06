# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :bigint           not null
#  user_bank_account_id :bigint           not null
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require "rails_helper"

RSpec.describe Investment, type: :model do
  include FactoryHelper

  let!(:investment) { create(:investment, :random, date: Date.new(2023, 7, 1)) }
  let!(:money_transaction) { investment.money_transaction }
  let!(:investments) do
    build_list(:investment, 3, :random, user: investment.user, user_bank_account: investment.user_bank_account, date: investment.date) do |inv, i|
      inv.save(date: investment.date + i + 1)
    end
  end

  shared_examples "investment cop" do
    it "sums the investments correctly" do
      expect(money_transaction.price).to be_within(0.01).of money_transaction.investments.sum(:price).round(2)
    end

    it "generates the comment that references every investments day" do
      expect(money_transaction.mt_comment).to include(money_transaction.investments.order(:date).map(&:day).join(", "))
    end
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(investment).to be_valid
      end

      %i[price date].each do |attribute|
        it_behaves_like "validate_nil", :investment, attribute
        it_behaves_like "validate_blank", :investment, attribute
      end
    end

    context "( associations )" do
      %i[user user_bank_account money_transaction].each do |model|
        it "belongs_to #{model}" do
          expect(investment).to respond_to model
        end
      end

      %i[categories].each do |model|
        it "has_many #{model}" do
          expect(investment).to respond_to model
        end
      end
    end

    context "( public methods )" do
      it "returns a formatted date" do
        investment.update(date: Date.new(2023, 12))
        expect(investment.month_year).to eq "DEC <23>"
      end
    end
  end

  # FIXME: move this to request spec when the view is ready
  describe "[ business logic ]" do
    context "( when new investments are created )" do
      before { money_transaction.reload }

      it "applies the right relationship to the money_transaction" do
        2.times do |i|
          expect(investments[i].money_transaction).to eq investments[i + 1].money_transaction
        end
      end

      include_examples "investment cop"
    end

    context "( when existing investments are updated )" do
      before do
        investments.each do |inv|
          inv.update(price: Faker::Number.decimal(l_digits: rand(0..1)))
        end

        money_transaction.reload
      end

      include_examples "investment cop"
    end

    context "( when most investments are deleted )" do
      before do
        investments.each(&:destroy)
        money_transaction.reload
      end

      it "finds in money_transaction.investments only the third element" do
        investments.each do |inv|
          expect(money_transaction.investments).not_to include(inv)
        end
        expect(money_transaction.investments).to include(investment)
      end

      include_examples "investment cop"
    end

    context "( when all investments are deleted )" do
      before { [ investment, *investments ].each(&:destroy) }

      it "deletes all investments" do
        [ investment, *investments ].each do |inv|
          expect(inv).to be_destroyed
        end
      end

      it "deletes the corresponding money_transaction" do
        expect(MoneyTransaction.find_by(id: money_transaction.id)).to be_nil
      end
    end

    context "( when the user_bank_account is changed )" do
      before { money_transaction.reload }

      it "creates or uses another money_transaction that fits the FK change" do
        expect(investment.money_transaction).to eq money_transaction
        expect(investment.money_transaction.investments.count).to eq(investments.size + 1)
        expect(investment.money_transaction.price).to be_within(0.01).of([ investment, *investments ].sum(&:price).round(2))

        investment.update(user_bank_account: random_custom_create(:user_bank_account, reference: { user: investment.user }))
        investments.first.money_transaction.reload

        expect(investment.money_transaction).to_not eq money_transaction
        expect(investment.money_transaction.investments.count).to eq(1)
        expect(investments.first.money_transaction.investments.count).to eq(investments.size)
        expect(investments.first.money_transaction.price).to be_within(0.01).of(investments.sum(&:price).round(2))
      end
    end
  end
end
