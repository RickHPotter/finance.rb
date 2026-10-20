# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Noncredit card transactions", type: :model do
  let(:user) { create(:user, :random) }
  let(:card) { create(:card, :random) }

  def noncredit_card(kind)
    bank_account = create(:user_bank_account, :random, user:) if kind == "debit"
    create(:user_card, user:, card:, card_kind: kind, user_bank_account: bank_account)
  end

  def purchase(user_card:, date:)
    CardTransaction.new(user:, context: user.main_context, user_card:, date:, description: "Purchase", price: -1000).tap do |transaction|
      transaction.card_installments.first.price = -1000
      transaction.build_month_year
    end
  end

  %w[prepaid debit].each do |kind|
    it "saves a #{kind} purchase in its purchase month without an invoice or reference" do
      user_card = noncredit_card(kind)
      date = Time.zone.today - 1.day
      transaction = purchase(user_card:, date:)

      expect { transaction.save! }.not_to change(Reference, :count)

      installment = transaction.card_installments.first.reload
      expect(transaction.reload.attributes.values_at("month", "year")).to eq([ date.month, date.year ])
      expect(installment.attributes.values_at("month", "year")).to eq([ date.month, date.year ])
      expect(installment.cash_transaction_id).to be_nil
      expect(installment).to be_paid
      expect(transaction).to be_paid
    end

    it "keeps a future #{kind} purchase unpaid until explicitly confirmed" do
      transaction = purchase(user_card: noncredit_card(kind), date: Time.zone.today + 1.month)

      transaction.save!

      expect(transaction.card_installments.first.reload).not_to be_paid
      expect(transaction.reload).not_to be_paid
    end

    it "rejects multiple installments on a #{kind} purchase" do
      transaction = purchase(user_card: noncredit_card(kind), date: Time.zone.today)
      transaction.card_installments.build(number: 2, date: transaction.date, price: -500, month: transaction.month, year: transaction.year)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:card_installments]).to be_present
    end
  end

  it "rejects switching a persisted credit purchase to prepaid without creating a reference" do
    credit_card = create(:user_card, user:, card:)
    transaction = purchase(user_card: credit_card, date: Time.zone.today)
    transaction.save!
    prepaid_card = create(:user_card, user:, card:, card_kind: "prepaid", user_card_name: "Food card")
    reference_count = Reference.count

    transaction.user_card = prepaid_card
    transaction.build_month_year

    expect(transaction).not_to be_valid
    expect(transaction.errors[:user_card]).to be_present
    expect(Reference.count).to eq(reference_count)
  end
end
