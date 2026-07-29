# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::CategoryPlanner do
  let(:user) { create(:user) }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }
  let(:transaction) do
    create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: create(:user_bank_account, :random, user:)
    )
  end

  def action(operation, source_id: nil, destination_id: nil)
    AllocationMutations::Action.new(allocation_type: :category, operation:, source_id:, destination_id:)
  end

  def plan(owner, operation, source_id: nil, destination_id: nil)
    described_class.new(owner:, action: action(operation, source_id:, destination_id:)).call
  end

  it "plans add, remove, and switch from the final category set without writing" do
    transaction.category_transactions.create!(category: source)

    expect do
      add_plan = plan(transaction, :add, destination_id: destination.id)
      remove_plan = plan(transaction, :remove, source_id: source.id)
      switch_plan = plan(transaction, :switch, source_id: source.id, destination_id: destination.id)

      expect(add_plan).to be_eligible
      expect(add_plan.category_ids_after).to contain_exactly(source.id, destination.id)
      expect(remove_plan).to be_eligible
      expect(remove_plan.category_ids_after).to be_empty
      expect(switch_plan).to be_eligible
      expect(switch_plan.category_ids_after).to contain_exactly(destination.id)
    end.not_to change(CategoryTransaction, :count)
  end

  it "returns idempotent no-ops for satisfied or absent operations" do
    transaction.category_transactions.create!(category: destination)

    expect(plan(transaction, :add, destination_id: destination.id).outcome).to have_attributes(status: :noop, reason_code: :destination_present)
    expect(plan(transaction, :remove, source_id: source.id).outcome).to have_attributes(status: :noop, reason_code: :source_absent)
    expect(plan(transaction, :switch, source_id: destination.id,
                                      destination_id: destination.id).outcome).to have_attributes(status: :noop, reason_code: :same_category)
  end

  it "collapses a switch onto an existing destination in the projected state" do
    transaction.category_transactions.create!(category: source)
    transaction.category_transactions.create!(category: destination)

    result = plan(transaction, :switch, source_id: source.id, destination_id: destination.id)

    expect(result).to be_eligible
    expect(result.category_ids_after).to contain_exactly(destination.id)
  end

  it "rejects foreign, inactive, and built-in categories" do
    foreign = create(:category, user: create(:user, :random), category_name: "FOREIGN")
    inactive = create(:category, user:, category_name: "INACTIVE")
    inactive.update!(active: false)
    built_in = user.built_in_category("INVESTMENT")

    expect(plan(transaction, :add, destination_id: foreign.id).outcome.reason_code).to eq(:category_not_owned)
    expect(plan(transaction, :add, destination_id: inactive.id).outcome.reason_code).to eq(:category_inactive)
    expect(plan(transaction, :add, destination_id: built_in.id).outcome.reason_code).to eq(:category_protected)
  end

  it "allows a custom correction beside a protected built-in on paid history" do
    transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
    transaction.cash_installments.first.update_column(:paid, true)

    result = plan(transaction.reload, :add, destination_id: destination.id)

    expect(result).to be_eligible
    expect(result.category_ids_after).to contain_exactly(user.built_in_category("EXCHANGE").id, destination.id)
  end

  it "protects a custom category inherited from a subscription" do
    subscription = create(:subscription, user:)
    subscription.categories << source
    subscription.attach_transactions!([ transaction ])

    result = plan(transaction.reload, :remove, source_id: source.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :subscription_owned_category)
  end

  it "rejects removing the final allocation from a budget" do
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      budget_categories: [ build(:budget_category, category: source) ]
    )

    result = plan(budget, :remove, source_id: source.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :invalid_final_state)
    expect(result.outcome.details[:errors]).to be_present
  end

  it "detects a duplicate budget produced by the final category set" do
    create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [ build(:budget_category, category: destination) ]
    )
    budget = create(
      :budget,
      user:,
      context: user.main_context,
      month: 7,
      year: 2026,
      budget_categories: [ build(:budget_category, category: source) ]
    )

    result = plan(budget, :switch, source_id: source.id, destination_id: destination.id)

    expect(result.outcome).to have_attributes(status: :conflict, reason_code: :invalid_final_state)
  end
end
