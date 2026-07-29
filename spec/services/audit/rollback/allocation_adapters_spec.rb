# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit rollback allocation adapters" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:transaction) do
    PaperTrail.request(enabled: false) do
      create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        category_transactions: [],
        entity_transactions: []
      )
    end
  end
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id: context.id) }

  def version_attributes(record)
    {
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: record.class.name,
      item_subtype: record.class.name,
      item_id: record.id,
      mutation_source: :web,
      metadata: Audit::VersionMetadata.for(record)
    }
  end

  def record_create(record)
    state = record.attributes.except(*record.class.paper_trail_options.fetch(:skip))
    AuditVersion.create!(
      **version_attributes(record),
      event: :create,
      object: nil,
      object_changes: state.transform_values { |value| [ nil, value ] }
    )
  end

  def record_update(record, before:, changes:)
    AuditVersion.create!(**version_attributes(record), event: :update, object: before, object_changes: changes)
  end

  def record_destroy(record, state:)
    AuditVersion.create!(
      **version_attributes(record),
      event: :destroy,
      object: state,
      object_changes: state.transform_values { |value| [ value, nil ] }
    )
  end

  def apply
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

  it "destroys a newly created category allocation and recalculates category totals" do
    category = create(:category, :random, user:)
    allocation = PaperTrail.request(enabled: false) { create(:category_transaction, category:, transactable: transaction) }
    record_create(allocation)

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.sole.dependencies).to contain_exactly(
      have_attributes(record_type: "CashTransaction", item_id: transaction.id, relationship: "parent", included: false)
    )
    expect(result).to have_attributes(status: "applied")
    expect(CategoryTransaction).not_to exist(allocation.id)
    expect(category.reload.cash_transactions_count).to eq(0)
  end

  it "restores an entity allocation update through its live transaction parent" do
    original_entity = create(:entity, :random, user:)
    current_entity = create(:entity, :random, user:)
    allocation = PaperTrail.request(enabled: false) do
      create(:entity_transaction, entity: current_entity, transactable: transaction, price: -500, price_to_be_returned: 500)
    end
    before = allocation.attributes.except(*EntityTransaction.paper_trail_options.fetch(:skip)).merge(
      "entity_id" => original_entity.id,
      "price" => -1_000,
      "price_to_be_returned" => 1_000
    )
    record_update(
      allocation,
      before:,
      changes: {
        "entity_id" => [ original_entity.id, current_entity.id ],
        "price" => [ -1_000, -500 ],
        "price_to_be_returned" => [ 1_000, 500 ]
      }
    )

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(allocation.reload).to have_attributes(entity_id: original_entity.id, price: -1_000, price_to_be_returned: 1_000)
  end

  it "recreates a destroyed category allocation with its original identity" do
    category = create(:category, :random, user:)
    allocation = PaperTrail.request(enabled: false) { create(:category_transaction, category:, transactable: transaction) }
    state = allocation.attributes.except(*CategoryTransaction.paper_trail_options.fetch(:skip))
    allocation_id = allocation.id
    PaperTrail.request(enabled: false) { allocation.destroy! }
    record_destroy(allocation, state:)

    preview, result = apply

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(CategoryTransaction.find(allocation_id)).to have_attributes(category_id: category.id, transactable: transaction)
  end

  it "reports a conflicting allocation key before apply" do
    category = create(:category, :random, user:)
    historical_allocation = PaperTrail.request(enabled: false) { create(:category_transaction, category:, transactable: transaction) }
    state = historical_allocation.attributes.except(*CategoryTransaction.paper_trail_options.fetch(:skip))
    historical_id = historical_allocation.id
    PaperTrail.request(enabled: false) do
      historical_allocation.destroy!
      create(:category_transaction, category:, transactable: transaction)
    end
    record_destroy(historical_allocation, state:)

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.sole.conflicts.map(&:code)).to include("allocation_key_taken")
    expect(CategoryTransaction).not_to exist(historical_id)
  end
end
