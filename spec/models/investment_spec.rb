# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  price                :integer          not null
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

  let!(:subject) { create(:investment, :random, date: Date.new(2023, 7, 1)) }
  let!(:money_transaction) { subject.money_transaction }
  let!(:investments) do
    build_list(:investment, 3, :random, user: subject.user, user_bank_account: subject.user_bank_account, date: subject.date) do |inv, i|
      inv.save(date: subject.date + i + 1)
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
        expect(subject).to be_valid
      end

      %i[price date].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      ob_models = %i[money_transaction]
      bt_models = %i[user user_bank_account]
      hm_models = %i[category_transactions categories]
      na_models = %i[category_transactions]

      ob_models.each { |model| it { should belong_to(model).optional } }
      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
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
          inv.update(price: Faker::Number.number(digits: rand(3..4)))
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
        expect(money_transaction.investments).to include(subject)
      end

      include_examples "investment cop"
    end

    context "( when all investments are deleted )" do
      before { [ subject, *investments ].each(&:destroy) }

      it "deletes all investments" do
        [ subject, *investments ].each do |inv|
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
        expect(subject.money_transaction).to eq money_transaction
        expect(subject.money_transaction.investments.count).to eq(investments.size + 1)
        expect(subject.money_transaction.price).to be_within(0.01).of([ subject, *investments ].sum(&:price).round(2))

        subject.update(user_bank_account: random_custom_create(:user_bank_account, reference: { user: subject.user }))
        investments.first.money_transaction.reload

        expect(subject.money_transaction).to_not eq money_transaction
        expect(subject.money_transaction.investments.count).to eq(1)
        expect(investments.first.money_transaction.investments.count).to eq(investments.size)
        expect(investments.first.money_transaction.price).to be_within(0.01).of(investments.sum(&:price).round(2))
      end
    end
  end
end
