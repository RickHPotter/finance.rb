# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashTransactable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:user_card_two) { create(:user_card, :random, user:, card:) }

  let(:card_transaction_one) do
    build(:card_transaction, :random, user:, user_card:, price: -200, date: Date.current,
                                      card_installments: build_list(:card_installment, 2, price: -100) { |ci, i| ci.number = i + 1 },
                                      category_transactions: [])
  end

  let(:card_transaction_two) do
    build(:card_transaction, :random, user:, user_card:, price: -300, date: Date.current,
                                      card_installments: build_list(:card_installment, 3, price: -100) { |ci, i| ci.number = i + 1 },
                                      category_transactions: [])
  end

  def validate(card_transaction, installments_prices)
    cash_transactions = card_transaction.card_installments.map(&:cash_transaction)

    expect(cash_transactions.count).to eq cash_transactions.compact_blank.count

    cash_transactions.each_with_index do |cash_transaction, index|
      expect(cash_transaction.comment).to eq "Upfront: 0, Installments: #{installments_prices[index]}"
    end
  end

  def validate_multiple(card_transactions, installments_prices)
    card_transactions.each do |card_transaction|
      validate(card_transaction, installments_prices)
    end
  end

  describe "[ concern behaviour ]" do
    before do
      card_transaction_one.save
    end

    it "attaches a cash_transaction on create" do
      validate(card_transaction_one, [ -100, -100 ])
    end

    it "updates a cash_transaction on price update" do
      card_transaction_one.price = -400
      card_transaction_one.card_installments.first.price = -200
      card_transaction_one.card_installments.second.price = -200
      card_transaction_one.save

      validate(card_transaction_one, [ -200, -200 ])
    end

    it "switches and deletes old cash_transaction on user_card update" do
      old_cash_transactions = card_transaction_one.card_installments.map(&:cash_transaction)

      card_transaction_one.update(user_card: user_card_two)

      expect(CashTransaction.where(id: old_cash_transactions.pluck(:id))).to be_empty
      validate(card_transaction_one, [ -100, -100 ])
    end

    it "switches and deletes old cash_transaction on month_year update" do
      old_cash_transactions = card_transaction_one.card_installments.map(&:cash_transaction)
      new_date = card_transaction_one.date + 4.months

      card_transaction_one.update(date: new_date, month: new_date.month, year: new_date.year)

      expect(CashTransaction.where(id: old_cash_transactions.pluck(:id))).to be_empty
      validate(card_transaction_one, [ -100, -100 ])
    end

    context "when multiple transactions exist" do
      before { card_transaction_two.save }

      it "updates cash_transaction on destroy as one of the card_installments" do
        validate_multiple(CardTransaction.all, [ -200, -200, -100 ])

        card_transaction_one.card_installments.last.destroy

        validate_multiple(CardTransaction.all, [ -200, -100, -100 ])
      end

      it "destroys cash_transaction on destroy as the only card_installment" do
        validate_multiple(CardTransaction.all, [ -200, -200, -100 ])

        card_transaction_two.card_installments.third.destroy

        validate_multiple(CardTransaction.all, [ -200, -200 ])
      end
    end
  end
end
