# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::EntityPlanner do
  let(:user) { create(:user) }
  let(:source) { create(:entity, user:, entity_name: "SOURCE") }
  let(:destination) { create(:entity, user:, entity_name: "DESTINATION") }
  let(:transaction) do
    create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: create(:user_bank_account, :random, user:)
    )
  end

  def action(operation, source_id: nil, destination_id: nil)
    AllocationMutations::Action.new(allocation_type: :entity, operation:, source_id:, destination_id:)
  end

  def plan(owner, operation, source_id: nil, destination_id: nil)
    described_class.new(owner:, action: action(operation, source_id:, destination_id:)).call
  end

  def add_neutral(owner, entity)
    owner.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
  end

  it "plans add, remove, and switch from the final entity set without writing" do
    add_neutral(transaction, source)

    expect do
      add_plan = plan(transaction, :add, destination_id: destination.id)
      remove_plan = plan(transaction, :remove, source_id: source.id)
      switch_plan = plan(transaction, :switch, source_id: source.id, destination_id: destination.id)

      expect(add_plan).to be_eligible
      expect(add_plan.entity_ids_after).to contain_exactly(source.id, destination.id)
      expect(remove_plan).to be_eligible
      expect(remove_plan.entity_ids_after).to be_empty
      expect(switch_plan).to be_eligible
      expect(switch_plan.entity_ids_after).to contain_exactly(destination.id)
    end.not_to change(EntityTransaction, :count)
  end

  it "returns idempotent no-ops before inspecting an existing destination's monetary state" do
    transaction.entity_transactions.create!(
      entity: destination,
      is_payer: true,
      price: transaction.price,
      price_to_be_returned: transaction.price
    )

    expect(plan(transaction, :add, destination_id: destination.id).outcome).to have_attributes(status: :noop, reason_code: :destination_present)
    expect(plan(transaction, :remove, source_id: source.id).outcome).to have_attributes(status: :noop, reason_code: :source_absent)
    expect(plan(transaction, :switch, source_id: destination.id,
                                      destination_id: destination.id).outcome).to have_attributes(status: :noop, reason_code: :same_entity)
  end

  it "rejects every monetary meaning on a remove or switch source" do
    allocation = transaction.entity_transactions.create!(
      entity: source,
      is_payer: true,
      price: 100,
      price_to_be_returned: 200
    )
    allocation.exchanges.create!(
      number: 1,
      exchange_type: :non_monetary,
      price: 0,
      date: Date.new(2026, 7, 1),
      month: 7,
      year: 2026
    )

    result = plan(transaction.reload, :switch, source_id: source.id, destination_id: destination.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :entity_allocation_not_neutral)
    expect(result.outcome.details[:reasons]).to contain_exactly(:payer, :price, :return, :exchanges)
  end

  it "rejects foreign, inactive, built-in, and friend-backed identities" do
    foreign = create(:entity, user: create(:user, :random), entity_name: "FOREIGN")
    inactive = create(:entity, user:, entity_name: "INACTIVE")
    inactive.update!(active: false)
    built_in = user.built_in_entity
    friend = create(:entity, user:, entity_name: "FRIEND", entity_user: create(:user, :random))

    expect(plan(transaction, :add, destination_id: foreign.id).outcome.reason_code).to eq(:entity_not_owned)
    expect(plan(transaction, :add, destination_id: inactive.id).outcome.reason_code).to eq(:entity_inactive)
    expect(plan(transaction, :add, destination_id: built_in.id).outcome.reason_code).to eq(:entity_protected)
    expect(plan(transaction, :add, destination_id: friend.id).outcome.reason_code).to eq(:entity_protected)
  end

  it "allows a neutral correction on an ordinary paid transaction" do
    add_neutral(transaction, source)
    transaction.cash_installments.first.update_column(:paid, true)

    result = plan(transaction.reload, :switch, source_id: source.id, destination_id: destination.id)

    expect(result).to be_eligible
  end

  it "protects generated, Exchange, shared-return, and Piggy Bank structures" do
    structures = {
      generated_projection: [ "Investment", user.built_in_category("INVESTMENT") ],
      exchange: [ nil, user.built_in_category("EXCHANGE") ],
      shared_return: [ "Exchange", user.built_in_category("EXCHANGE RETURN") ],
      piggy_bank: [ nil, user.built_in_category("PIGGY BANK") ]
    }

    structures.each_value do |cash_transaction_type, category|
      owner = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, :random, user:),
        cash_transaction_type:
      )
      owner.category_transactions.create!(category:)
      add_neutral(owner, source)

      expect(plan(owner.reload, :remove, source_id: source.id).outcome.reason_code).to eq(:structural_entity_allocation)
    end
  end

  it "protects entities inherited from a subscription" do
    subscription = create(:subscription, user:)
    subscription.entities << source
    subscription.attach_transactions!([ transaction ])

    result = plan(transaction.reload, :remove, source_id: source.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :subscription_owned_entity)
  end

  it "rejects removing the final allocation from a budget" do
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: source) ]
    )

    result = plan(budget, :remove, source_id: source.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :invalid_final_state)
  end

  it "detects a duplicate budget produced by the final entity set" do
    create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: destination) ]
    )
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: source) ]
    )

    result = plan(budget, :switch, source_id: source.id, destination_id: destination.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :invalid_final_state)
  end
end
