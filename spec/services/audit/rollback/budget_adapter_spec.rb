# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Budget do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

  def create_budget
    create(
      :budget,
      user:,
      context:,
      budget_categories: [ build(:budget_category, category:) ],
      budget_entities: [ build(:budget_entity, entity:) ]
    )
  end

  def apply(operation)
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

  it "audits and reverses creation of a complete Budget graph" do
    budget = nil
    operation = nil
    Audit::Operation.run(actor: user, context:, source: :web) do
      budget = create_budget
      operation = Audit::Operation.ensure_persisted!
    end
    original_ids = {
      budget: budget.id,
      category: budget.budget_categories.sole.id,
      entity: budget.budget_entities.sole.id
    }

    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_type)).to contain_exactly("Budget", "BudgetCategory", "BudgetEntity")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Budget).not_to exist(original_ids[:budget])
    expect(BudgetCategory).not_to exist(original_ids[:category])
    expect(BudgetEntity).not_to exist(original_ids[:entity])
  end

  it "recreates a destroyed Budget with its exact allocations and identities" do
    budget = PaperTrail.request(enabled: false) { create_budget }
    original_ids = {
      budget: budget.id,
      category: budget.budget_categories.sole.id,
      entity: budget.budget_entities.sole.id
    }
    operation = nil
    Audit::Operation.run(actor: user, context:, source: :web) do
      budget.destroy!
      operation = Audit::Operation.ensure_persisted!
    end

    preview, result = apply(operation)

    restored = Budget.find(original_ids[:budget])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(restored.budget_categories.sole).to have_attributes(id: original_ids[:category], category_id: category.id)
    expect(restored.budget_entities.sole).to have_attributes(id: original_ids[:entity], entity_id: entity.id)
  end

  it "restores an allocation replacement when the Budget itself has no material version" do
    original_category = category
    replacement_category = create(:category, :random, user:)
    budget = PaperTrail.request(enabled: false) { create_budget }
    original_allocation_id = budget.budget_categories.sole.id
    operation = nil

    Audit::Operation.run(actor: user, context:, source: :web) do
      budget.update!(
        budget_categories_attributes: [
          { id: original_allocation_id, category_id: original_category.id, _destroy: true },
          { category_id: replacement_category.id }
        ]
      )
      operation = Audit::Operation.ensure_persisted!
    end

    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_type).uniq).to eq([ "BudgetCategory" ])
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(budget.reload.budget_categories.sole).to have_attributes(id: original_allocation_id, category_id: original_category.id)
  end
end
