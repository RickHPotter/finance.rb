# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category and Entity merge rollback" do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:admin) { create(:user, :random, admin: true) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }

  def apply_rollback(operation, preview: Audit::Rollback::Preview.new(operation:, actor: admin))
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: false
    ).call
    [ preview, result ]
  end

  def apply_category_merge(source:, destination:)
    plan = CategoryMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id).call
    token = CategoryMerges::PreviewToken.generate(plan)
    CategoryMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true).call
  end

  def apply_entity_merge(source:, destination:, mode:)
    plan = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode:).call
    token = EntityMerges::PreviewToken.generate(plan)
    EntityMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true, mode:).call
  end

  it "fully restores a strict Category merge, its collapsed joins, and affected Budget" do
    source = create(:category, user:, category_name: "ROLLBACK CATEGORY SOURCE")
    destination = create(:category, user:, category_name: "ROLLBACK CATEGORY DESTINATION")
    transferred = create(:cash_transaction, user:, context:, user_bank_account: bank_account, category_transactions: [])
    transferred.category_transactions.create!(category: source)
    collapsed = create(:cash_transaction, user:, context:, user_bank_account: bank_account, category_transactions: [])
    collapsed.category_transactions.create!(category: source)
    collapsed.category_transactions.create!(category: destination)
    budget = create(
      :budget,
      user:,
      context:,
      month: 8,
      year: 2026,
      budget_categories: [ build(:budget_category, category: source) ],
      budget_entities: []
    )
    original_budget_description = budget.description

    merged = apply_category_merge(source:, destination:)
    preview, rolled_back = apply_rollback(merged.operation)

    expect(merged).to be_applied
    expect(merged.operation.audit_versions.where(item_type: "Category", item_id: source.id, event: :destroy)).to exist
    expect(preview).to have_attributes(state: "previewable")
    expect(rolled_back).to have_attributes(status: "applied")
    expect(rolled_back.operation.audit_versions.where(item_type: "Category", item_id: source.id, event: :create)).to exist
    expect(Category.find(source.id)).to have_attributes(category_name: "ROLLBACK CATEGORY SOURCE")
    expect(transferred.reload.categories).to contain_exactly(source)
    expect(collapsed.reload.categories).to contain_exactly(source, destination)
    expect(budget.reload.categories).to contain_exactly(source)
    expect(budget.description).to eq(original_budget_description)
    expect(source.reload.cash_transactions_count).to eq(2)
    expect(destination.reload.cash_transactions_count).to eq(1)
  end

  it "fully restores a strict Entity merge, its collapsed joins, and affected Budget" do
    friend = create(:user, :random)
    source = create(:entity, user:, entity_name: "ROLLBACK ENTITY SOURCE", entity_user: friend)
    destination = create(:entity, user:, entity_name: "ROLLBACK ENTITY DESTINATION", entity_user: friend)
    transferred = create(:cash_transaction, user:, context:, user_bank_account: bank_account, entity_transactions: [])
    transferred.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)
    collapsed = create(:cash_transaction, user:, context:, user_bank_account: bank_account, entity_transactions: [])
    collapsed.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)
    collapsed.entity_transactions.create!(entity: destination, price: 0, price_to_be_returned: 0, is_payer: false)
    budget = create(
      :budget,
      user:,
      context:,
      month: 8,
      year: 2026,
      budget_categories: [],
      budget_entities: [ build(:budget_entity, entity: source) ]
    )
    original_budget_description = budget.description

    merged = apply_entity_merge(source:, destination:, mode: :strict)
    preview, rolled_back = apply_rollback(merged.operation)

    expect(merged).to be_applied
    expect(merged.operation.audit_versions.where(item_type: "Entity", item_id: source.id, event: :destroy)).to exist
    expect(preview).to have_attributes(state: "previewable")
    expect(rolled_back).to have_attributes(status: "applied")
    expect(rolled_back.operation.audit_versions.where(item_type: "Entity", item_id: source.id, event: :create)).to exist
    expect(Entity.find(source.id)).to have_attributes(entity_name: "ROLLBACK ENTITY SOURCE")
    expect(source.reload.entity_user_id).to eq(friend.id)
    expect(transferred.reload.entities).to contain_exactly(source)
    expect(collapsed.reload.entities).to contain_exactly(source, destination)
    expect(budget.reload.entities).to contain_exactly(source)
    expect(budget.description).to eq(original_budget_description)
    expect(source.reload.cash_transactions_count).to eq(2)
    expect(destination.reload.cash_transactions_count).to eq(1)
  end

  it "restores only the transferred subset of an eligible-only Entity merge" do
    source = create(:entity, user:, entity_name: "PARTIAL ENTITY SOURCE")
    destination = create(:entity, user:, entity_name: "PARTIAL ENTITY DESTINATION")
    neutral = create(:cash_transaction, user:, context:, user_bank_account: bank_account, entity_transactions: [])
    neutral.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)
    neutral.entity_transactions.create!(entity: destination, price: 0, price_to_be_returned: 0, is_payer: false)
    monetary = create(:cash_transaction, user:, context:, user_bank_account: bank_account, entity_transactions: [])
    monetary.entity_transactions.create!(entity: source, price: 100, price_to_be_returned: 0, is_payer: false)

    merged = apply_entity_merge(source:, destination:, mode: :eligible_only)
    preview, rolled_back = apply_rollback(merged.operation)

    expect(merged).to be_applied
    expect(merged.operation.audit_versions.where(item_type: "Entity", item_id: source.id)).not_to exist
    expect(preview).to have_attributes(state: "previewable")
    expect(rolled_back).to have_attributes(status: "applied")
    expect(source.reload).to be_persisted
    expect(neutral.reload.entities).to contain_exactly(source, destination)
    expect(monetary.reload.entities).to contain_exactly(source)
    expect(source.reload.cash_transactions_count).to eq(2)
    expect(destination.reload.cash_transactions_count).to eq(1)
  end

  it "rejects a stale merge rollback after a moved allocation diverges" do
    source = create(:category, user:, category_name: "STALE CATEGORY SOURCE")
    destination = create(:category, user:, category_name: "STALE CATEGORY DESTINATION")
    replacement = create(:category, user:, category_name: "STALE CATEGORY REPLACEMENT")
    transaction = create(:cash_transaction, user:, context:, user_bank_account: bank_account, category_transactions: [])
    allocation = transaction.category_transactions.create!(category: source)
    merged = apply_category_merge(source:, destination:)
    preview = Audit::Rollback::Preview.new(operation: merged.operation, actor: admin)
    allocation.reload.update_columns(category_id: replacement.id)

    _locked_preview, rolled_back = apply_rollback(merged.operation, preview:)

    expect(rolled_back).to have_attributes(status: "rejected", reason_code: "stale_preview")
    expect(Category.exists?(source.id)).to be(false)
    expect(transaction.reload.categories).to contain_exactly(replacement)
  end

  it "marks rollback conflicted when the deleted master's natural key is reused" do
    source = create(:category, user:, category_name: "REUSED CATEGORY SOURCE")
    destination = create(:category, user:, category_name: "REUSED CATEGORY DESTINATION")
    transaction = create(:cash_transaction, user:, context:, user_bank_account: bank_account, category_transactions: [])
    transaction.category_transactions.create!(category: source)
    merged = apply_category_merge(source:, destination:)
    destination.update!(category_name: "REUSED CATEGORY SOURCE")

    preview = Audit::Rollback::Preview.new(operation: merged.operation, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.find { |row| row.record_type == "Category" }.conflicts.map(&:code)).to include("master_key_taken")
  end

  it "rolls back the compensation transaction when post-restore integrity fails" do
    source = create(:category, user:, category_name: "ATOMIC CATEGORY SOURCE")
    destination = create(:category, user:, category_name: "ATOMIC CATEGORY DESTINATION")
    transaction = create(:cash_transaction, user:, context:, user_bank_account: bank_account, category_transactions: [])
    transaction.category_transactions.create!(category: source)
    merged = apply_category_merge(source:, destination:)
    preview = Audit::Rollback::Preview.new(operation: merged.operation, actor: admin)
    allow_any_instance_of(Audit::Rollback::IntegrityVerifier).to receive(:call).and_raise(Audit::Rollback::IntegrityVerifier::IntegrityError)

    _locked_preview, rolled_back = apply_rollback(merged.operation, preview:)

    expect(rolled_back).to have_attributes(status: "failed", reason_code: "integrity_failed")
    expect(Category.exists?(source.id)).to be(false)
    expect(transaction.reload.categories).to contain_exactly(destination)
  end
end
