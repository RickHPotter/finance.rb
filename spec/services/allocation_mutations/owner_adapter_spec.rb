# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::OwnerAdapter do
  it "adapts cash and card transactions through their polymorphic allocations" do
    user = User.new(id: 1)
    context = Context.new(id: 2, user:)
    cash = CashTransaction.new(id: 3, user:, context:, date: Date.new(2026, 6, 1), month: 6, year: 2026, price: 100)
    card = CardTransaction.new(id: 4, user:, context:, date: Date.new(2026, 6, 1), month: 7, year: 2026, price: -100)
    cash.cash_installments.each { |installment| installment.assign_attributes(month: 6, year: 2026) }
    card.card_installments.each { |installment| installment.assign_attributes(month: 7, year: 2026) }

    [ cash, card ].each do |transaction|
      adapter = described_class.for(transaction)

      expect(adapter.owner).to eq(transaction)
      expect(adapter.owner_type).to eq(transaction.class.name)
      expect(adapter.category_allocations).to eq(transaction.category_transactions)
      expect(adapter.entity_allocations).to eq(transaction.entity_transactions)
      expect(adapter.reference_months).to eq(transaction.installments.map { |installment| Date.new(installment.year, installment.month, 1) }.uniq.sort)
    end
  end

  it "adapts budgets through their dedicated allocation joins" do
    user = User.new(id: 1)
    context = Context.new(id: 2, user:)
    budget = Budget.new(id: 3, user:, context:, month: 7, year: 2026)
    adapter = described_class.for(budget)

    expect(adapter.owner).to eq(budget)
    expect(adapter.category_allocations).to eq(budget.budget_categories)
    expect(adapter.entity_allocations).to eq(budget.budget_entities)
    expect(adapter.reference_months).to eq([ Date.new(2026, 7, 1) ])
  end

  it "rejects owner types outside the V1 contract" do
    expect { described_class.for(Investment.new) }.to raise_error(described_class::UnsupportedOwner, /Investment/)
  end
end
