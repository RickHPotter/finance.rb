# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::StructuralFamily do
  it "classifies built-in and generated transaction structures" do
    user = User.new(id: 1)
    context = Context.new(id: 2, user:)
    category = Category.new(id: 3, user:, built_in: true, category_name: "PIGGY BANK")
    transaction = CashTransaction.new(id: 4, user:, context:, cash_transaction_type: "PiggyBank", date: Date.new(2026, 7, 1), month: 7, year: 2026, price: 100)
    transaction.category_transactions.build(category:)

    expect(described_class.call(transaction)).to contain_exactly(:generated_projection, :piggy_bank)
  end

  it "classifies subscription, payer, exchange, and friend identity boundaries" do
    user = User.new(id: 1)
    friend = User.new(id: 2)
    context = Context.new(id: 3, user:)
    entity = Entity.new(id: 4, user:, entity_user: friend)
    transaction = CardTransaction.new(id: 5, user:, context:, subscription_id: 99, date: Date.new(2026, 7, 1), month: 8, year: 2026, price: -100)
    transaction.entity_transactions.build(entity:, is_payer: true, exchanges_count: 1)

    expect(described_class.call(transaction)).to contain_exactly(:exchange_bearing_entity, :friend_identity, :payer_entity, :subscription_owned)
  end

  it "leaves an ordinary budget unclassified" do
    user = User.new(id: 1)
    context = Context.new(id: 2, user:)

    expect(described_class.call(Budget.new(id: 3, user:, context:, month: 7, year: 2026))).to eq([])
  end
end
