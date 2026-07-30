# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::PaidHistoryEnvelope do
  def paid_cash_transaction
    create(:cash_transaction).tap do |transaction|
      transaction.cash_installments.first.update_column(:paid, true)
      transaction.reload
    end
  end

  def paid_card_transaction
    create(:card_transaction).tap do |transaction|
      transaction.card_installments.first.update_column(:paid, true)
      transaction.reload
    end
  end

  it "accepts description, comment, and same-reference cash date changes" do
    transaction = paid_cash_transaction
    installment = transaction.cash_installments.load.first

    transaction.assign_attributes(description: "Corrected", comment: "Metadata only", date: transaction.date + 1.day)
    installment.date += 1.day

    expect(described_class.new(transaction).safe?).to be(true)
  end

  it "accepts a card date correction when its billing references stay unchanged" do
    transaction = paid_card_transaction
    installment = transaction.card_installments.load.first

    transaction.date += 1.day
    installment.date += 1.day

    expect(described_class.new(transaction).safe?).to be(true)
  end

  it "rejects parent and installment price changes" do
    transaction = paid_cash_transaction
    installment = transaction.cash_installments.load.first

    transaction.price += 100
    expect(described_class.new(transaction).safe?).to be(false)

    transaction.price = transaction.attribute_in_database("price")
    installment.price += 100
    expect(described_class.new(transaction).safe?).to be(false)
  end

  it "rejects reference-period changes" do
    transaction = paid_card_transaction

    transaction.month += 1

    expect(described_class.new(transaction).safe?).to be(false)
  end

  it "rejects installment creation, removal, and non-date edits" do
    transaction = paid_cash_transaction
    installment = transaction.cash_installments.load.first

    transaction.cash_installments.build(
      number: 2,
      price: 0,
      date: installment.date + 1.month,
      month: (installment.date + 1.month).month,
      year: (installment.date + 1.month).year,
      paid: false
    )
    expect(described_class.new(transaction).safe?).to be(false)

    transaction.reload
    transaction.cash_installments.load.first.mark_for_destruction
    expect(described_class.new(transaction).safe?).to be(false)

    transaction.reload
    transaction.cash_installments.load.first.number += 1
    expect(described_class.new(transaction).safe?).to be(false)
  end

  it "does not apply to new or unsupported owners" do
    expect(described_class.new(CashTransaction.new).safe?).to be(false)
    expect(described_class.new(Budget.new).safe?).to be(false)
  end
end
