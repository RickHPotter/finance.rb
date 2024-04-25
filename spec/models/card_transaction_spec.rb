# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                   :bigint           not null, primary key
#  ct_description       :string           not null
#  ct_comment           :text
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  installments_count   :integer          default(0), not null
#  user_id              :bigint           not null
#  user_card_id         :bigint           not null
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require "rails_helper"

include FactoryHelper

RSpec.describe CardTransaction, type: :model do
  let!(:card_transaction) { create(:card_transaction, :random) }
  let(:money_transaction) { card_transaction.money_transaction }
  let!(:card_transactions) do
    build_list(:card_transaction, 3, :random,
               user: card_transaction.user,
               user_card: card_transaction.user_card,
               date: card_transaction.date)
  end

  shared_examples "card_transaction cop" do
    it "sums the card_transactions correctly" do
      expect(money_transaction.price).to be_within(0.01).of money_transaction.card_transactions.sum(:price).round(2)
    end
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(card_transaction).to be_valid
      end

      %i[date ct_description price].each do |attribute|
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

      %i[categories installments].each do |model|
        it "has_many #{model}" do
          expect(card_transaction).to respond_to model
        end
      end
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns a formatted date" do
        card_transaction.update(date: Date.new(2023, 12))
        expect(card_transaction.month_year).to eq "DEC <23>"
      end
    end

    context "( when the card_transactions are created )" do
      before { card_transaction.money_transaction.reload }

      it "applies the right relationship to the money_transaction" do
        2.times do |i|
          expect(card_transactions[i].money_transaction).to eq card_transactions[i + 1].money_transaction
        end
      end

      include_examples "card_transaction cop"
    end

    context "( when existing card_transactions are updated )" do
      before do
        card_transactions.each do |ct|
          ct.update(price: Faker::Number.decimal(l_digits: rand(0..1)))
        end

        money_transaction.reload
      end

      include_examples "card_transaction cop"
    end

    context "( when an existing card_transaction changes fk )" do
      before do
        card_transactions.each(&:save)
        money_transaction.reload
      end

      it "creates or uses another money_transaction that fits the FK change" do
        expect(card_transaction.money_transaction).to eq money_transaction
        expect(card_transaction.money_transaction.card_transactions.count).to eq(card_transactions.size + 1)
        expect(card_transaction.money_transaction.price).to be_within(0.01).of([ card_transaction, *card_transactions ].sum(&:price).round(2))

        card_transaction.update(user_card: random_custom_create(:user_card, reference: { user: card_transaction.user }))
        card_transactions.first.money_transaction.reload

        expect(card_transaction.money_transaction).to_not eq money_transaction
        expect(card_transaction.money_transaction.card_transactions.count).to eq(1)
        expect(card_transactions.first.money_transaction.card_transactions.count).to eq(card_transactions.size)
        expect(card_transactions.first.money_transaction.price).to be_within(0.01).of(card_transactions.sum(&:price).round(2))
      end
    end

    context "( when most card_transactions are deleted )" do
      before do
        card_transactions.each(&:destroy)
      end

      it "finds in money_transaction.card_transactions only the third element" do
        expect(money_transaction.card_transactions).to include(card_transaction)
        card_transactions.each do |ct|
          expect(money_transaction.card_transactions).not_to include(ct)
        end
      end

      include_examples "card_transaction cop"
    end

    context "( when all card_transactions are deleted )" do
      before do
        card_transaction.destroy
        card_transactions.each(&:destroy)
      end

      it "deletes all card_transactions" do
        [ *card_transactions, card_transaction ].each do |ct|
          expect(ct).to be_destroyed
        end
      end

      it "deletes the corresponding money_transaction" do
        expect(MoneyTransaction.find_by(id: money_transaction.id)).to be_nil
      end
    end
  end
end
