# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::Apply do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:source) { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  def transaction(description)
    create(
      :cash_transaction,
      user:,
      context:,
      description:,
      user_bank_account: create(:user_bank_account, :random, user:),
      category_transactions: []
    )
  end

  def category_action(operation: :add, source_id: nil, destination_id: destination.id)
    AllocationMutations::Action.new(allocation_type: :category, operation:, source_id:, destination_id:)
  end

  def entity_action(operation:, source_id: nil, destination_id: nil)
    AllocationMutations::Action.new(allocation_type: :entity, operation:, source_id:, destination_id:)
  end

  def preview(owners:, action:, selected_row_count: owners.size)
    AllocationMutations::BatchPlanner.new(
      actor: user,
      context:,
      owner_type: owners.first.class.base_class.name,
      owner_ids: owners.map(&:id),
      selected_row_count:,
      action:
    ).call
  end

  def apply(current_preview, **options)
    described_class.new(
      actor: options.fetch(:actor, user),
      context: options.fetch(:current_context, context),
      request_id: SecureRandom.uuid,
      token: options.fetch(:token, current_preview.apply_token),
      mode: options.fetch(:mode, :strict),
      confirmed: options.fetch(:confirmed, true)
    ).call
  end

  it "replans and atomically applies a strict preview under one bounded root audit operation" do
    owners = [ transaction("First"), transaction("Second") ]
    current_preview = preview(owners:, action: category_action, selected_row_count: 3)
    operation_count = AuditOperation.count

    result = apply(current_preview)

    expect(result).to be_applied
    expect(result).not_to be_duplicate
    expect(result.impacts.map(&:owner_id)).to match_array(owners.map(&:id))
    expect(owners.flat_map { |owner| owner.reload.category_ids }).to eq([ destination.id, destination.id ])
    expect(AuditOperation.count).to eq(operation_count + 1)
    expect(result.operation.audit_versions.where(item_type: "CategoryTransaction").count).to eq(2)
    expect(result.operation.metadata).to include(
      "allocation_mutation" => true,
      "owner_type" => "CashTransaction",
      "allocation_type" => "category",
      "action" => "add",
      "mode" => "strict",
      "selected_row_count" => 3,
      "owner_count" => 2,
      "affected_count" => 2,
      "preview_digest" => current_preview.digest
    )
    expect(result.operation.metadata.to_json.bytesize).to be < 2.kilobytes
    expect(result.operation.metadata.values).to all(satisfy { |value| value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value.in?([ true, false ]) })
  end

  it "does not run ledger balance recalculation for a descriptive transaction allocation" do
    owner = transaction("Descriptive correction")
    current_preview = preview(owners: [ owner ], action: category_action)
    expect(Logic::RecalculateBalancesService).not_to receive(:new)

    result = apply(current_preview)

    expect(result).to be_applied
    expect(owner.reload.categories).to contain_exactly(destination)
  end

  it "consolidates changed Budget criteria into one earliest-month balance recalculation" do
    account = create(:user_bank_account, :random, user:)
    [ 7, 8 ].each do |month|
      matching_transaction = create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        date: Date.new(2026, month, 10),
        month:,
        year: 2026,
        price: -2_000,
        cash_installments: [ build(:cash_installment, price: -2_000, number: 1) ],
        category_transactions: []
      )
      matching_transaction.category_transactions.create!(category: destination)
    end
    budgets = [ 7, 8 ].map do |month|
      create(
        :budget,
        user:,
        context:,
        month:,
        year: 2026,
        value: -10_000,
        budget_categories: [ build(:budget_category, category: source) ]
      )
    end
    current_preview = preview(
      owners: budgets,
      action: category_action(operation: :switch, source_id: source.id, destination_id: destination.id)
    )
    expect(Logic::RecalculateBalancesService).to receive(:new).once.with(
      user:,
      context:,
      year: 2026,
      month: 7
    ).and_call_original

    result = apply(current_preview)

    expect(result).to be_applied
    expect(budgets.map { |budget| budget.reload.remaining_value }).to eq([ -8_000, -8_000 ])
  end

  it "skips balance recalculation when Budget criteria leave persisted balance inputs unchanged" do
    budget = create(
      :budget,
      user:,
      context:,
      month: 7,
      year: 2026,
      value: -10_000,
      budget_categories: [ build(:budget_category, category: source) ]
    )
    current_preview = preview(
      owners: [ budget ],
      action: category_action(operation: :switch, source_id: source.id, destination_id: destination.id)
    )
    expect(Logic::RecalculateBalancesService).not_to receive(:new)

    result = apply(current_preview)

    expect(result).to be_applied
    expect(budget.reload).to have_attributes(remaining_value: -10_000)
  end

  it "allows strict application with no-ops and mutates only affected owners" do
    eligible = transaction("Eligible")
    noop = transaction("No-op")
    noop.category_transactions.create!(category: destination)
    current_preview = preview(owners: [ eligible, noop ], action: category_action)

    result = apply(current_preview)

    expect(result).to be_applied
    expect(result.impacts.map(&:owner_id)).to eq([ eligible.id ])
    expect(result.operation.metadata).to include("affected_count" => 1, "noop_count" => 1, "conflict_count" => 0)
    expect(eligible.reload.categories).to contain_exactly(destination)
    expect(noop.reload.categories).to contain_exactly(destination)
  end

  it "rolls back every eligible owner and its audit history when one mutation fails" do
    owners = [ transaction("First"), transaction("Second") ]
    current_preview = preview(owners:, action: category_action)
    operation_count = AuditOperation.count
    calls = 0

    allow_any_instance_of(AllocationMutations::CategoryMutator).to receive(:call).and_wrap_original do |method|
      calls += 1
      raise ActiveRecord::RecordInvalid, method.receiver.owner if calls == 2

      method.call
    end

    result = apply(current_preview)

    expect(result).to be_rejected
    expect(result.reason_code).to eq("validation_failed")
    expect(owners.flat_map { |owner| owner.reload.category_ids }).to be_empty
    expect(AuditOperation.count).to eq(operation_count)
  end

  it "rejects strict application when any owner conflicts without mutating or auditing" do
    entity = create(:entity, user:, entity_name: "ENTITY")
    ordinary = transaction("Ordinary")
    payer = transaction("Payer")
    ordinary.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    payer.entity_transactions.create!(entity:, is_payer: true, price: 100, price_to_be_returned: 100)
    current_preview = preview(owners: [ ordinary, payer ], action: entity_action(operation: :remove, source_id: entity.id))
    operation_count = AuditOperation.count

    result = apply(current_preview)

    expect(result).to be_rejected
    expect(result.reason_code).to eq("strict_apply_unavailable")
    expect(ordinary.reload.entity_ids).to contain_exactly(entity.id)
    expect(payer.reload.entity_ids).to contain_exactly(entity.id)
    expect(AuditOperation.count).to eq(operation_count)
  end

  it "applies only the independent eligible subset as one explicit atomic operation" do
    entity = create(:entity, user:, entity_name: "ENTITY")
    ordinary = transaction("Ordinary")
    payer = transaction("Payer")
    ordinary.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    payer.entity_transactions.create!(entity:, is_payer: true, price: 100, price_to_be_returned: 100)
    current_preview = preview(owners: [ ordinary, payer ], action: entity_action(operation: :remove, source_id: entity.id))

    result = apply(current_preview, mode: :eligible_only)

    expect(result).to be_applied
    expect(result.impacts.map(&:owner_id)).to eq([ ordinary.id ])
    expect(ordinary.reload.entities).to be_empty
    expect(payer.reload.entities).to contain_exactly(entity)
    expect(result.operation.metadata).to include(
      "mode" => "eligible_only",
      "affected_count" => 1,
      "conflict_count" => 1
    )
  end

  it "rejects eligible-only application for inseparable structural conflicts" do
    entity = create(:entity, user:, entity_name: "ENTITY")
    ordinary = transaction("Ordinary")
    structural = transaction("Structural")
    ordinary.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    structural.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    structural.category_transactions.create!(category: user.built_in_category("PIGGY BANK"))
    current_preview = preview(owners: [ ordinary, structural ], action: entity_action(operation: :remove, source_id: entity.id))

    result = apply(current_preview, mode: :eligible_only)

    expect(result).to be_rejected
    expect(result.reason_code).to eq("eligible_only_unavailable")
    expect(ordinary.reload.entities).to contain_exactly(entity)
  end

  it "rejects allocation drift after preview and leaves the new current state intact" do
    owner = transaction("Drift")
    current_preview = preview(owners: [ owner ], action: category_action)
    concurrent = create(:category, user:, category_name: "CONCURRENT")
    owner.category_transactions.create!(category: concurrent)
    operation_count = AuditOperation.count

    result = apply(current_preview)

    expect(result).to be_rejected
    expect(result.reason_code).to eq("stale_preview")
    expect(owner.reload.categories).to contain_exactly(concurrent)
    expect(AuditOperation.count).to eq(operation_count)
  end

  it "rejects tampered, expired, foreign-actor, foreign-context, and unconfirmed requests" do
    owner = transaction("Protected")
    current_preview = preview(owners: [ owner ], action: category_action)
    other_user = create(:user, :random)

    expect(apply(current_preview, token: "#{current_preview.apply_token}tampered").reason_code).to eq("invalid_token")
    expect(apply(current_preview, actor: other_user).reason_code).to eq("token_actor_mismatch")
    expect(apply(current_preview, current_context: other_user.main_context).reason_code).to eq("token_context_mismatch")
    expect(apply(current_preview, confirmed: false).reason_code).to eq("confirmation_required")
    travel 16.minutes do
      expect(apply(current_preview).reason_code).to eq("invalid_token")
    end
    expect(owner.reload.categories).to be_empty
  end

  it "returns the first operation for an idempotent retry without applying twice" do
    owner = transaction("Retry")
    current_preview = preview(owners: [ owner ], action: category_action)

    first = apply(current_preview)
    second = apply(current_preview)

    expect(first).to be_applied
    expect(second).to be_applied
    expect(second).to be_duplicate
    expect(second.operation).to eq(first.operation)
    expect(owner.reload.categories).to contain_exactly(destination)
    expect(first.operation.audit_versions.where(item_type: "CategoryTransaction").count).to eq(1)
  end
end
