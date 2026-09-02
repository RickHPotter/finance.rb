# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::EntityMutator do
  let(:user) { create(:user) }
  let(:source) { create(:entity, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, user:, entity_name: "DESTINATION") }
  let(:transaction) do
    create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: create(:user_card, user:),
      category_transactions: [],
      entity_transactions: []
    )
  end

  def entity_plan(owner, operation, source_id: nil, destination_id: nil)
    action = AllocationMutations::Action.new(allocation_type: :entity, operation:, source_id:, destination_id:)
    AllocationMutations::EntityPlanner.new(owner:, action:).call
  end

  def add_neutral(owner, entity)
    owner.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
  end

  it "adds a deterministic neutral row and returns its impact" do
    installment = transaction.card_installments.first
    matching_budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: installment.month,
      year: installment.year,
      value: -10_000,
      remaining_value: -10_000,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: destination) ]
    )
    plan = entity_plan(transaction, :add, destination_id: destination.id)

    impact = described_class.new(plan:).call
    AllocationMutations::ImpactRecalculator.new(actor: user, context: user.main_context, impacts: [ impact ]).call

    allocation = transaction.reload.entity_transactions.sole
    expect(allocation).to have_attributes(
      entity_id: destination.id,
      is_payer: false,
      price: 0,
      price_to_be_returned: 0,
      loan_return_percentage: 0.to_d,
      status: "finished",
      exchanges_count: 0
    )
    expect(destination.reload).to have_attributes(card_transactions_count: 1, card_transactions_total: transaction.price)
    expect(matching_budget.reload.remaining_value).to eq(0)
    expect(impact).to have_attributes(entity_ids_before: [], entity_ids_after: [ destination.id ])
    expect(impact).to be_entity_changed
  end

  it "removes a neutral allocation" do
    add_neutral(transaction, source)
    plan = entity_plan(transaction.reload, :remove, source_id: source.id)

    described_class.new(plan:).call

    expect(transaction.reload.entities).to be_empty
  end

  it "switches a neutral source onto an existing payer destination without changing it" do
    source_allocation = add_neutral(transaction, source)
    destination_allocation = transaction.entity_transactions.create!(
      entity: destination,
      is_payer: true,
      price: transaction.price,
      price_to_be_returned: transaction.price
    )
    plan = entity_plan(transaction.reload, :switch, source_id: source.id, destination_id: destination.id)

    expect do
      described_class.new(plan:).call
    end.to change(EntityTransaction, :count).by(-1)

    expect(EntityTransaction.exists?(source_allocation.id)).to be(false)
    expect(destination_allocation.reload).to have_attributes(
      price: transaction.price,
      price_to_be_returned: transaction.price,
      is_payer: true
    )
  end

  it "applies a Budget switch and captures its reference month" do
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: source) ]
    )
    plan = entity_plan(budget, :switch, source_id: source.id, destination_id: destination.id)
    expect(Logic::RecalculateBalancesService).not_to receive(:new)

    impact = described_class.new(plan:).call

    expect(budget.reload.entities).to contain_exactly(destination)
    expect(impact.reference_months).to eq([ Date.new(2026, 7, 1) ])
  end

  it "refreshes a Budget description after entity add, switch, and remove" do
    category = create(:category, user:, category_name: "FOOD")
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      description: "Stale description",
      inclusive: false,
      budget_categories: [ build(:budget_category, category:) ],
      budget_entities: [ build(:budget_entity, entity: source) ]
    )

    described_class.new(plan: entity_plan(budget, :add, destination_id: destination.id)).call
    expect(budget.reload.description).to eq("[ FOOD ] || ( SOURCE | DESTINATION )")

    described_class.new(plan: entity_plan(budget, :switch, source_id: source.id, destination_id: destination.id)).call
    expect(budget.reload.description).to eq("[ FOOD ] || ( DESTINATION )")

    described_class.new(plan: entity_plan(budget, :remove, source_id: destination.id)).call
    expect(budget.reload.description).to eq("[ FOOD ]")
  end

  it "refuses ineligible and stale plans" do
    noop_plan = entity_plan(transaction, :remove, source_id: source.id)
    built_in = user.built_in_entity
    conflict_plan = entity_plan(transaction, :add, destination_id: built_in.id)

    expect { described_class.new(plan: noop_plan).call }.to raise_error(described_class::IneligiblePlan)
    expect { described_class.new(plan: conflict_plan).call }.to raise_error(described_class::IneligiblePlan)

    eligible_plan = entity_plan(transaction, :add, destination_id: destination.id)
    add_neutral(transaction, source)

    expect { described_class.new(plan: eligible_plan).call }.to raise_error(described_class::StalePlan)
    expect(transaction.reload.entities).to contain_exactly(source)
  end
end
