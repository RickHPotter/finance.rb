# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashTransactable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:, user_card_name: "Primary #{card.card_name}") }
  let(:user_card_two) { create(:user_card, :random, user:, card:, user_card_name: "Secondary #{card.card_name}") }
  let(:base_date) { Time.zone.today.beginning_of_month + 1.month + 9.days + 12.hours }

  let(:card_transaction_one) do
    build(
      :card_transaction,
      user:,
      user_card:,
      price: -200,
      date: base_date,
      month: base_date.month,
      year: base_date.year,
      card_installments: build_card_installments(starting_on: base_date, prices: [ -100, -100 ]),
      category_transactions: []
    )
  end

  let(:card_transaction_two) do
    build(
      :card_transaction,
      user:,
      user_card:,
      price: -300,
      date: base_date,
      month: base_date.month,
      year: base_date.year,
      card_installments: build_card_installments(starting_on: base_date, prices: [ -100, -100, -100 ]),
      category_transactions: []
    )
  end

  def build_card_installments(starting_on:, prices:)
    prices.each_with_index.map do |price, index|
      installment_date = starting_on + index.months

      build(
        :card_installment,
        price:,
        number: index + 1,
        date: installment_date,
        month: installment_date.month,
        year: installment_date.year
      )
    end
  end

  def validate(installments_prices)
    CashTransaction.order(:year, :month).each_with_index do |cash_transaction, index|
      expected_comment = cash_transaction.card_installments.first&.comment
      expect(cash_transaction.comment).to eq(expected_comment)
      expect(cash_transaction.price).to eq installments_prices[index]
    end
  end

  describe "[ concern behaviour ]" do
    before do
      card_transaction_one.save
    end

    it "attaches a cash_transaction on create" do
      validate([ -100, -100 ])
    end

    it "updates a cash_transaction on price update" do
      card_transaction_one.price = -400
      card_transaction_one.card_installments.first.price = -200
      card_transaction_one.card_installments.second.price = -200
      card_transaction_one.save

      validate([ -200, -200 ])
    end

    it "switches and deletes old cash_transaction on user_card update" do
      old_cash_transactions = card_transaction_one.card_installments.map(&:cash_transaction)

      card_transaction_one.update(user_card: user_card_two)

      expect(CashTransaction.where(id: old_cash_transactions.pluck(:id))).to be_empty
      validate([ -100, -100 ])
    end

    it "switches and deletes old cash_transaction on month_year update" do
      old_cash_transactions = card_transaction_one.card_installments.map(&:cash_transaction)
      new_date = card_transaction_one.date + 4.months

      card_transaction_one.date = new_date
      card_transaction_one.month = new_date.month
      card_transaction_one.year = new_date.year
      card_transaction_one.card_installments.each do |ci|
        ci.date = nil
        ci.month = nil
        ci.year = nil
      end
      card_transaction_one.save

      expect(CashTransaction.where(id: old_cash_transactions.pluck(:id))).to be_empty
      validate([ -100, -100 ])
    end

    context "( when multiple transactions exist )" do
      before { card_transaction_two.save }

      it "updates cash_transaction on destroy of one card_transaction" do
        validate([ -200, -200, -100 ])

        card_transaction_one.destroy

        validate([ -100, -100, -100 ])
      end

      it "destroys one cash_transaction on destroy of one card_transaction" do
        validate([ -200, -200, -100 ])

        card_transaction_two.destroy

        validate([ -100, -100 ])
      end
    end

    context "( destroying card_transaction )" do
      before { card_transaction_one.save }

      it "ceases to exist" do
        cash_transactions_ids = card_transaction_one.card_installments.map(&:cash_transaction).compact.pluck(:id)
        cash_installments_ids = card_transaction_one.card_installments.map(&:cash_transaction).compact.map(&:cash_installments).flatten.pluck(:id)

        card_transaction_one.destroy

        expect(card_transaction_one).to be_destroyed
        expect(CashTransaction.where(id: cash_transactions_ids)).to be_empty
        expect(CashInstallment.where(id: cash_installments_ids)).to be_empty
      end
    end
  end
end
