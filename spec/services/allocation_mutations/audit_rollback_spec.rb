# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Allocation mutation audit rollback" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

  def apply_allocation(owner:, allocation_type:, destination_id:)
    action = AllocationMutations::Action.new(allocation_type:, operation: :add, destination_id:)
    preview = AllocationMutations::BatchPlanner.new(
      actor: user,
      context:,
      owner_type: owner.class.base_class.name,
      owner_ids: [ owner.id ],
      selected_row_count: 1,
      action:
    ).call

    AllocationMutations::Apply.new(
      actor: user,
      context:,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      mode: :strict,
      confirmed: true
    ).call
  end

  def rollback(operation)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token
    ).call

    [ preview, result ]
  end

  it "rolls back a CategoryTransaction created by the bulk workflow" do
    transaction = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      category_transactions: []
    )
    applied = apply_allocation(owner: transaction, allocation_type: :category, destination_id: category.id)
    allocation_id = transaction.reload.category_transactions.sole.id

    preview, result = rollback(applied.operation)

    expect(applied.operation.audit_versions.pluck(:item_type)).to eq([ "CategoryTransaction" ])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(CategoryTransaction).not_to exist(allocation_id)
    expect(category.reload.cash_transactions_count).to eq(0)
  end

  it "rolls back an EntityTransaction created by the bulk workflow" do
    transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card: create(:user_card, user:),
      entity_transactions: []
    )
    applied = apply_allocation(owner: transaction, allocation_type: :entity, destination_id: entity.id)
    allocation_id = transaction.reload.entity_transactions.sole.id

    preview, result = rollback(applied.operation)

    expect(applied.operation.audit_versions.pluck(:item_type)).to eq([ "EntityTransaction" ])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(EntityTransaction).not_to exist(allocation_id)
    expect(entity.reload.card_transactions_count).to eq(0)
  end

  it "rolls back a BudgetCategory created by the bulk workflow" do
    original_entity = create(:entity, :random, user:)
    budget = create(
      :budget,
      user:,
      context:,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: original_entity) ]
    )
    applied = apply_allocation(owner: budget, allocation_type: :category, destination_id: category.id)
    allocation_id = budget.reload.budget_categories.sole.id

    preview, result = rollback(applied.operation)

    expect(applied.operation.audit_versions.pluck(:item_type)).to eq([ "BudgetCategory" ])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(BudgetCategory).not_to exist(allocation_id)
    expect(budget.reload.entities).to contain_exactly(original_entity)
  end

  it "rolls back a BudgetEntity created by the bulk workflow" do
    original_category = create(:category, :random, user:)
    budget = create(
      :budget,
      user:,
      context:,
      budget_categories: [ build(:budget_category, category: original_category) ],
      budget_entities: []
    )
    applied = apply_allocation(owner: budget, allocation_type: :entity, destination_id: entity.id)
    allocation_id = budget.reload.budget_entities.sole.id

    preview, result = rollback(applied.operation)

    expect(applied.operation.audit_versions.pluck(:item_type)).to eq([ "BudgetEntity" ])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(BudgetEntity).not_to exist(allocation_id)
    expect(budget.reload.categories).to contain_exactly(original_category)
  end
end
