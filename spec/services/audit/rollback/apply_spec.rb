# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Apply do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id: context.id) }

  def create_transaction(description: "Current transaction")
    PaperTrail.request(enabled: false) do
      create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        description:,
        price: 5_000,
        date: Date.new(2026, 7, 19),
        cash_installments: [ build(:cash_installment, price: 5_000, number: 1, paid: false) ]
      )
    end
  end

  def create_card_transaction
    card = create(:user_card, :random, user:)
    PaperTrail.request(enabled: false) do
      create(
        :card_transaction,
        user:,
        context:,
        user_card: card,
        description: "Current card transaction",
        price: -5_000,
        date: Date.new(2026, 7, 19),
        card_installments: [ build(:card_installment, price: -5_000, number: 1, paid: false) ],
        category_transactions: [],
        entity_transactions: []
      )
    end
  end

  def snapshot(record)
    record.attributes.except(*record.class.paper_trail_options.fetch(:skip)).compact
  end

  def version_attributes(record)
    {
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: record.class.base_class.name,
      item_subtype: record.class.name,
      item_id: record.id,
      mutation_source: :web,
      metadata: Audit::VersionMetadata.for(record)
    }
  end

  def record_update(record, before:, changes:)
    AuditVersion.create!(
      **version_attributes(record),
      event: :update,
      object: before,
      object_changes: changes
    )
  end

  def record_create(record, state: snapshot(record))
    AuditVersion.create!(
      **version_attributes(record),
      event: :create,
      object: nil,
      object_changes: state.transform_values { |value| [ nil, value ] }
    )
  end

  def record_destroy(record, state: snapshot(record))
    AuditVersion.create!(
      **version_attributes(record),
      event: :destroy,
      object: state,
      object_changes: state.transform_values { |value| [ value, nil ] }
    )
  end

  def apply(preview: Audit::Rollback::Preview.new(operation:, actor: admin), confirmed: false)
    described_class.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed:
    ).call
  end

  it "restores an update, writes a linked rollback operation, and remains idempotent" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => "Original transaction")
    record_update(
      transaction,
      before:,
      changes: { "description" => [ "Original transaction", transaction.description ] }
    )
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    original_version_payload = operation.audit_versions.sole.attributes

    first_result = apply(preview:)
    rollback_version_count = first_result.operation.audit_versions.count
    second_result = apply(preview:)

    expect(first_result).to have_attributes(status: "applied", duplicate: false)
    expect(first_result.operation).to have_attributes(
      source: "rollback",
      result: "committed",
      actor_id: admin.id,
      rollback_of_operation_id: operation.id
    )
    expect(first_result.operation.metadata).to include("preview_digest" => preview.digest, "idempotency_key" => be_present)
    expect(transaction.reload.description).to eq("Original transaction")
    expect(first_result.operation.audit_versions).to include(have_attributes(item_type: "CashTransaction", item_id: transaction.id, event: "update"))
    expect(operation.audit_versions.sole.attributes).to eq(original_version_payload)
    expect(second_result).to have_attributes(status: "applied", operation: first_result.operation, duplicate: true)
    expect(first_result.operation.audit_versions.count).to eq(rollback_version_count)
  end

  it "reverses a complete aggregate creation by destroying its transaction and installment" do
    transaction = create_transaction
    installment = transaction.cash_installments.sole
    record_create(transaction)
    record_create(installment)

    result = apply

    expect(result).to have_attributes(status: "applied", duplicate: false)
    expect(CashTransaction.unscoped).not_to exist(transaction.id)
    expect(CashInstallment.unscoped).not_to exist(id: installment.id, installment_type: "CashInstallment")
    expect(result.operation.audit_versions.pluck(:event)).to include("destroy")
    expect(account.reload).to have_attributes(cash_transactions_count: 0, cash_transactions_total: 0)
  end

  it "restores supported card transactions and recalculates their card totals" do
    transaction = create_card_transaction
    before = snapshot(transaction).merge("description" => "Original card transaction")
    record_update(transaction, before:, changes: { "description" => [ "Original card transaction", transaction.description ] })

    result = apply

    expect(result).to have_attributes(status: "applied", duplicate: false)
    expect(transaction.reload.description).to eq("Original card transaction")
    expect(transaction.user_card.reload).to have_attributes(
      card_transactions_count: 1,
      card_transactions_total: transaction.price
    )
  end

  it "recreates a destroyed aggregate with its original identities" do
    transaction = create_transaction(description: "Destroyed transaction")
    installment = transaction.cash_installments.sole
    transaction_state = snapshot(transaction)
    installment_state = snapshot(installment)
    transaction_id = transaction.id
    installment_id = installment.id
    PaperTrail.request(enabled: false) { transaction.destroy! }
    record_destroy(transaction, state: transaction_state)
    record_destroy(installment, state: installment_state)

    result = apply

    restored_transaction = CashTransaction.unscoped.find(transaction_id)
    restored_installment = CashInstallment.unscoped.find_by!(id: installment_id, installment_type: "CashInstallment")
    expect(result).to have_attributes(status: "applied", duplicate: false)
    expect(restored_transaction).to have_attributes(description: "Destroyed transaction", cash_installments_count: 1)
    expect(restored_installment).to have_attributes(cash_transaction_id: transaction_id, cash_installments_count: 1)
    expect(result.operation.audit_versions.pluck(:event)).to include("create")
    expect(account.reload).to have_attributes(cash_transactions_count: 1, cash_transactions_total: restored_transaction.price)
  end

  it "rejects a stale token without changing the current financial state" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => "Original transaction")
    record_update(transaction, before:, changes: { "description" => [ "Original transaction", transaction.description ] })
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    PaperTrail.request(enabled: false) { transaction.update_column(:description, "Later transaction") }
    version_count = AuditVersion.count

    result = apply(preview:)

    expect(result).to have_attributes(status: "rejected", reason_code: "stale_preview", duplicate: false)
    expect(result.operation).to have_attributes(source: "rollback", result: "rejected", rollback_of_operation_id: operation.id)
    expect(transaction.reload.description).to eq("Later transaction")
    expect(AuditVersion.count).to eq(version_count)
  end

  it "requires explicit confirmation before correcting paid history" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => "Original transaction")
    record_update(transaction, before:, changes: { "description" => [ "Original transaction", transaction.description ] })
    PaperTrail.request(enabled: false) do
      transaction.cash_installments.sole.update_column(:paid, true)
    end
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    result = apply(preview:)

    expect(preview).to be_confirmation_required
    expect(result).to have_attributes(status: "rejected", reason_code: "confirmation_required")
    expect(transaction.reload.description).to eq("Current transaction")
  end

  it "rolls all compensation changes back when integrity verification fails" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => "Original transaction")
    record_update(transaction, before:, changes: { "description" => [ "Original transaction", transaction.description ] })
    version_count = AuditVersion.count
    allow_any_instance_of(Audit::Rollback::IntegrityVerifier).to receive(:call).and_raise(Audit::Rollback::IntegrityVerifier::IntegrityError)

    result = apply

    expect(result).to have_attributes(status: "failed", reason_code: "integrity_failed")
    expect(transaction.reload.description).to eq("Current transaction")
    expect(AuditVersion.count).to eq(version_count)
    expect(result.operation).to have_attributes(source: "rollback", result: "failed", rollback_of_operation_id: operation.id)
  end

  it "rolls all compensation changes back when canonical recalculation fails" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => "Original transaction")
    record_update(transaction, before:, changes: { "description" => [ "Original transaction", transaction.description ] })
    version_count = AuditVersion.count
    allow_any_instance_of(Audit::Rollback::Recalculator).to receive(:call).and_raise("recalculation failed")

    result = apply

    expect(result).to have_attributes(status: "failed", reason_code: "unexpected_failure")
    expect(transaction.reload.description).to eq("Current transaction")
    expect(AuditVersion.count).to eq(version_count)
    expect(result.operation).to have_attributes(source: "rollback", result: "failed", rollback_of_operation_id: operation.id)
  end

  it "rejects an invalid historical state without retaining partial versions" do
    transaction = create_transaction
    before = snapshot(transaction).merge("description" => nil)
    record_update(transaction, before:, changes: { "description" => [ nil, transaction.description ] })
    version_count = AuditVersion.count

    result = apply

    expect(result).to have_attributes(status: "rejected", reason_code: "validation_failed")
    expect(transaction.reload.description).to eq("Current transaction")
    expect(AuditVersion.count).to eq(version_count)
    expect(result.operation).to have_attributes(source: "rollback", result: "rejected", rollback_of_operation_id: operation.id)
  end
end
