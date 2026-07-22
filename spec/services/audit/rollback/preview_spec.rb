# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Preview do
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
        description: "Current description",
        price: 5_000,
        date: Date.new(2026, 7, 19),
        cash_installments: [ build(:cash_installment, price: 5_000, number: 1, paid: false) ]
      )
    end
  end
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id: context.id) }

  def create_update_version(version_context_id: context.id)
    before = transaction.attributes.except(*CashTransaction.paper_trail_options.fetch(:skip)).merge("description" => "Previous description")
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: version_context_id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: transaction.id,
      event: :update,
      mutation_source: :web,
      object: before,
      object_changes: { "description" => [ "Previous description", transaction.description ] },
      metadata: { "user_bank_account_id" => account.id }
    )
  end

  it "produces a stable preview digest and signed token without writing financial history" do
    create_update_version
    version_count = AuditVersion.count
    operation_count = AuditOperation.count

    first_preview = described_class.new(operation:, actor: admin)
    second_preview = described_class.new(operation:, actor: admin)
    token_payload = Audit::Rollback::PreviewToken.verify(first_preview.apply_token)

    expect(first_preview).to have_attributes(state: "previewable", confirmation_required?: false)
    expect(first_preview.digest).to eq(second_preview.digest)
    expect(token_payload).to include("operation_id" => operation.id, "digest" => first_preview.digest, "actor_id" => admin.id)
    expect(AuditVersion.count).to eq(version_count)
    expect(AuditOperation.count).to eq(operation_count)
    expect(transaction.reload.description).to eq("Current description")
  end

  it "detects later canonical changes and changes the digest" do
    create_update_version
    original_preview = described_class.new(operation:, actor: admin)
    PaperTrail.request(enabled: false) { transaction.update_column(:description, "Later change") }

    conflicted_preview = described_class.new(operation:, actor: admin)

    expect(conflicted_preview.state).to eq("conflicted")
    expect(conflicted_preview.rows.sole.conflicts.map(&:code)).to include("current_state_changed")
    expect(conflicted_preview.digest).not_to eq(original_preview.digest)
  end

  it "ignores declared derived counters during current-state comparison" do
    create_update_version
    original_digest = described_class.new(operation:, actor: admin).digest
    PaperTrail.request(enabled: false) { transaction.update_column(:cash_installments_count, 99) }

    preview = described_class.new(operation:, actor: admin)

    expect(preview.state).to eq("previewable")
    expect(preview.digest).to eq(original_digest)
  end

  it "makes the whole operation read-only when any record family is unsupported" do
    create_update_version
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: "Budget",
      item_subtype: "Budget",
      item_id: 77,
      event: :update,
      mutation_source: :web,
      object: { "id" => 77, "user_id" => user.id, "context_id" => context.id },
      object_changes: { "price" => [ 100, 200 ] },
      metadata: {}
    )

    preview = described_class.new(operation:, actor: admin)

    expect(preview.state).to eq("read_only")
    expect(preview.rows.find { |row| row.record_type == "Budget" }.support_issues.map(&:code)).to eq([ "unsupported_record_type" ])
  end

  it "reports paid history as an explicit confirmation requirement" do
    create_update_version
    PaperTrail.request(enabled: false) { transaction.cash_installments.first.update_column(:paid, true) }

    preview = described_class.new(operation:, actor: admin)

    expect(preview.state).to eq("previewable")
    expect(preview).to be_confirmation_required
    expect(preview.rows.sole.requirements.map(&:code)).to include("historical_correction_confirmation")
  end

  it "reports later dependents that make create compensation unsafe" do
    snapshot = transaction.attributes.except(*CashTransaction.paper_trail_options.fetch(:skip))
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: transaction.id,
      event: :create,
      mutation_source: :web,
      object: nil,
      object_changes: snapshot.transform_values { |value| [ nil, value ] },
      metadata: { "user_bank_account_id" => account.id }
    )

    preview = described_class.new(operation:, actor: admin)
    row = preview.rows.sole

    expect(row.action).to eq("destroy")
    expect(row.dependencies).to include(have_attributes(record_type: "CashInstallment", included: false))
    expect(row.conflicts.map(&:code)).to include("later_dependencies")
    expect(preview.state).to eq("conflicted")
  end

  it "keeps an available external installment parent as a dependency without treating it as an orphan" do
    installment = transaction.cash_installments.first
    snapshot = installment.attributes.except(*Installment.paper_trail_options.fetch(:skip))
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: "Installment",
      item_subtype: "CashInstallment",
      item_id: installment.id,
      event: :create,
      mutation_source: :web,
      object: nil,
      object_changes: snapshot.transform_values { |value| [ nil, value ] },
      metadata: { "cash_transaction_id" => transaction.id }
    )

    preview = described_class.new(operation:, actor: admin)
    row = preview.rows.sole

    expect(row).to have_attributes(action: "destroy", conflicts: [])
    expect(row.dependencies).to contain_exactly(
      have_attributes(record_type: "CashTransaction", item_id: transaction.id, relationship: "parent", included: false)
    )
    expect(preview.state).to eq("previewable")
  end

  it "conflicts when an installment recreation has neither an included nor a live parent" do
    missing_parent_id = CashTransaction.maximum(:id).to_i + 10_000
    missing_installment_id = Installment.maximum(:id).to_i + 10_000
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: "Installment",
      item_subtype: "CashInstallment",
      item_id: missing_installment_id,
      event: :destroy,
      mutation_source: :web,
      object: {
        "id" => missing_installment_id,
        "installment_type" => "CashInstallment",
        "cash_transaction_id" => missing_parent_id,
        "number" => 1,
        "price" => 1_000,
        "starting_price" => 1_000,
        "paid" => false
      },
      object_changes: {},
      metadata: { "cash_transaction_id" => missing_parent_id }
    )

    preview = described_class.new(operation:, actor: admin)

    expect(preview.state).to eq("conflicted")
    expect(preview.rows.sole.conflicts.map(&:code)).to include("missing_parent_dependency")
  end

  it "blocks ownership and context identities that no longer resolve" do
    missing_context_id = Context.maximum(:id).to_i + 10_000
    create_update_version(version_context_id: missing_context_id)

    preview = described_class.new(operation:, actor: admin)

    expect(preview.state).to eq("prohibited")
    expect(preview.rows.sole.prohibitions.map(&:code)).to include("unknown_context")
  end
end
