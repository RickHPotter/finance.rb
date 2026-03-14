# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasAdvancePayments, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:card_advance_category) { user.built_in_category("CARD ADVANCE") }
  let(:other_category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:cycle_date) { Time.zone.today.beginning_of_month + 5.days }

  let!(:regular_card_transaction) do
    create(:card_transaction,
           :random,
           user:,
           user_card:,
           price: -500,
           date: cycle_date,
           card_installments: build_list(:card_installment, 1, price: -500) { |ci, i| ci.number = i + 1 },
           category_transactions: [])
  end

  let(:card_transaction) do
    build(:card_transaction,
          :random,
          user:,
          user_card:,
          price: 200,
          date: cycle_date,
          card_installments: build_list(:card_installment, 1, price: 200) { |ci, i| ci.number = i + 1 },
          category_transactions: [])
  end

  before do
    card_transaction.categories << card_advance_category
  end

  describe "[ concern behaviour ]" do
    it "creates an advance_cash_transaction when the CARD ADVANCE category is present" do
      card_transaction.save!

      expect(card_transaction.advance_cash_transaction).to be_present
      expect(card_transaction.advance_cash_transaction.price).to eq(-200)
      expect(card_transaction.card_advance_category?).to be(true)
    end

    it "removes the advance_cash_transaction when the CARD ADVANCE category is removed" do
      card_transaction.save!
      advance_cash_transaction_id = card_transaction.advance_cash_transaction_id

      card_transaction.categories = [ other_category ]
      card_transaction.save!

      expect(card_transaction.advance_cash_transaction).to be_nil
      expect(CashTransaction.find_by(id: advance_cash_transaction_id)).to be_nil
    end
  end
end
