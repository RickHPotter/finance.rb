# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::CategoryMutator do
  let(:user) { create(:user) }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }
  let(:transaction) do
    create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: create(:user_card, user:),
      category_transactions: []
    )
  end

  def category_plan(owner, operation, source_id: nil, destination_id: nil)
    action = AllocationMutations::Action.new(allocation_type: :category, operation:, source_id:, destination_id:)
    AllocationMutations::CategoryPlanner.new(owner:, action:).call
  end

  it "applies an add and returns the before/after impact" do
    installment = transaction.card_installments.first
    matching_budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: installment.month,
      year: installment.year,
      value: -10_000,
      remaining_value: -10_000,
      budget_categories: [ build(:budget_category, category: destination) ]
    )
    plan = category_plan(transaction, :add, destination_id: destination.id)

    impact = described_class.new(plan:).call

    expect(transaction.reload.categories).to contain_exactly(destination)
    expect(destination.reload).to have_attributes(card_transactions_count: 1, card_transactions_total: transaction.price)
    expect(matching_budget.reload.remaining_value).to eq(0)
    expect(impact).to have_attributes(
      owner_type: "CardTransaction",
      owner_id: transaction.id,
      category_ids_before: [],
      category_ids_after: [ destination.id ]
    )
    expect(impact).to be_category_changed
  end

  it "removes every matching source allocation" do
    transaction.category_transactions.create!(category: source)
    plan = category_plan(transaction.reload, :remove, source_id: source.id)

    described_class.new(plan:).call

    expect(transaction.reload.categories).to be_empty
  end

  it "switches by removing the source while retaining an existing destination row" do
    transaction.category_transactions.create!(category: source)
    destination_allocation = transaction.category_transactions.create!(category: destination)
    plan = category_plan(transaction.reload, :switch, source_id: source.id, destination_id: destination.id)

    expect do
      described_class.new(plan:).call
    end.to change(CategoryTransaction, :count).by(-1)

    expect(transaction.reload.category_transactions.sole).to eq(destination_allocation)
  end

  it "applies a budget switch and captures its reference month" do
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [ build(:budget_category, category: source) ]
    )
    plan = category_plan(budget, :switch, source_id: source.id, destination_id: destination.id)
    expect(Logic::RecalculateBalancesService).not_to receive(:new)

    impact = described_class.new(plan:).call

    expect(budget.reload.categories).to contain_exactly(destination)
    expect(impact.reference_months).to eq([ Date.new(2026, 7, 1) ])
  end

  it "recalculates from the Budget month when changed criteria alter its persisted remaining value" do
    matching_transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price: -2_000,
      cash_installments: [ build(:cash_installment, price: -2_000, number: 1) ],
      category_transactions: []
    )
    matching_transaction.category_transactions.create!(category: destination)
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      value: -10_000,
      budget_categories: [ build(:budget_category, category: source) ]
    )
    plan = category_plan(budget, :switch, source_id: source.id, destination_id: destination.id)
    expect(Logic::RecalculateBalancesService).to receive(:new).with(
      user:,
      context: user.main_context,
      year: 2026,
      month: 7
    ).and_call_original

    described_class.new(plan:).call

    expect(budget.reload.remaining_value).to eq(-8_000)
  end

  it "refuses to apply no-op and conflict plans" do
    noop_plan = category_plan(transaction, :remove, source_id: source.id)
    built_in = user.built_in_category("INVESTMENT")
    conflict_plan = category_plan(transaction, :add, destination_id: built_in.id)

    expect { described_class.new(plan: noop_plan).call }.to raise_error(described_class::IneligiblePlan)
    expect { described_class.new(plan: conflict_plan).call }.to raise_error(described_class::IneligiblePlan)
  end

  it "refuses a stale plan without applying its destination" do
    plan = category_plan(transaction, :add, destination_id: destination.id)
    concurrent_category = create(:category, user:, category_name: "CONCURRENT")
    transaction.category_transactions.create!(category: concurrent_category)

    expect do
      described_class.new(plan:).call
    end.to raise_error(described_class::StalePlan)

    expect(transaction.reload.categories).to contain_exactly(concurrent_category)
  end
end
