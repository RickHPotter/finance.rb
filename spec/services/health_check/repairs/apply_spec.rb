# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Repairs::Apply do
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { admin.main_context }
  let(:scope) { HealthCheck::Scope.new(user: admin, context:) }
  let(:transaction) do
    PaperTrail.request(enabled: false) do
      create(
        :cash_transaction,
        user: admin,
        context:,
        description: "Before repair",
        cash_installments: [ build(:cash_installment, number: 1, price: 500) ],
        price: 500
      )
    end
  end
  let(:change) do
    HealthCheck::Repairs::Change.new(
      record_type: "CashTransaction",
      record_id: transaction.id,
      attribute: "description",
      before: transaction.description,
      after: "After repair"
    )
  end
  let(:preview_result) do
    HealthCheck::Repairs::Result.new(
      finding_id: transaction.id,
      state: "previewable",
      changes: [ change ],
      references: [ { type: "CashTransaction", id: transaction.id, role: "source" } ]
    )
  end
  let(:planner_class) { class_double(HealthCheck::Repairs::CanonicalReferencePlanner) }
  let(:applier_class) { class_double(HealthCheck::Repairs::CanonicalReferenceApplier) }
  let(:planner) { instance_double(HealthCheck::Repairs::CanonicalReferencePlanner, call: preview_result) }
  let(:applier) { instance_double(HealthCheck::Repairs::CanonicalReferenceApplier) }
  let(:definition) do
    instance_double(
      HealthCheck::Repairs::Registry::Definition,
      check_key: "exchange_trio",
      key: "canonical_reference",
      planner: planner_class,
      applier: applier_class
    )
  end
  let(:preview) do
    HealthCheck::Repairs::Preview.new(
      check_key: definition.check_key,
      repair_key: definition.key,
      scope:,
      result: preview_result
    )
  end

  before do
    allow(planner_class).to receive(:new).and_return(planner)
    allow(applier_class).to receive(:new).and_return(applier)
    allow(applier).to receive(:call) { transaction.update!(description: "After repair") }
    allow(HealthCheck::Broadcaster).to receive(:call)
  end

  it "commits one audited admin repair and queues only the affected check after commit" do
    result = nil
    operation_count = AuditOperation.count
    version_count = AuditVersion.count
    expect do
      result = apply
    end.to have_enqueued_job(HealthCheck::RunJob).once

    operation = AuditOperation.find(result.operation_id)
    expect(result).to be_applied
    expect(result).to be_frozen
    expect(result.to_h.values).not_to include(an_instance_of(ApplicationRecord))
    expect(AuditOperation.count).to eq(operation_count + 1)
    expect(AuditVersion.count).to eq(version_count + 1)
    expect(result.rerun_reason).to eq("queued")
    expect(transaction.reload.description).to eq("After repair")
    expect(operation).to have_attributes(
      source: "admin_repair",
      result: "committed",
      actor_id: admin.id,
      context_id: context.id
    )
    expect(operation.metadata).to include(
      "health_check_key" => "exchange_trio",
      "repair_key" => "canonical_reference",
      "finding_key" => transaction.id.to_s,
      "preview_digest" => preview.digest
    )
    expect(operation.audit_versions.sole).to have_attributes(item_type: "CashTransaction", item_id: transaction.id)

    serialized_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
    restored_job = HealthCheck::RunJob.deserialize(serialized_job)
    expect(restored_job).to have_attributes(
      audit_parent_operation_id: operation.id,
      audit_actor_id: admin.id,
      audit_context_id: context.id
    )
  end

  it "returns the original operation for a repeated apply without applying or scheduling twice" do
    first = apply
    clear_enqueued_jobs
    operation_count = AuditOperation.count
    version_count = AuditVersion.count

    second = apply

    expect(second).to be_applied
    expect(second).to be_duplicate
    expect(second.operation_id).to eq(first.operation_id)
    expect(second.rerun_reason).to be_nil
    expect(AuditOperation.count).to eq(operation_count)
    expect(AuditVersion.count).to eq(version_count)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
  end

  it "rejects missing confirmation and tampered tokens without invoking the planner or applier" do
    expect(planner_class).not_to receive(:new)
    expect(applier_class).not_to receive(:new)

    unconfirmed = apply(confirmed: false)
    tampered = apply(token: "#{preview.apply_token}tampered")

    expect(unconfirmed).to have_attributes(status: "rejected", reason_code: "confirmation_required")
    expect(tampered).to have_attributes(status: "rejected", reason_code: "invalid_token")
    expect(transaction.reload.description).to eq("Before repair")
  end

  it "rejects a diverged preview without overwriting current data" do
    stale_result = HealthCheck::Repairs::Result.new(
      finding_id: transaction.id,
      state: "previewable",
      changes: [
        HealthCheck::Repairs::Change.new(
          record_type: "CashTransaction",
          record_id: transaction.id,
          attribute: "description",
          before: "Changed elsewhere",
          after: "After repair"
        )
      ]
    )
    allow(planner).to receive(:call).and_return(stale_result)
    expect(applier_class).not_to receive(:new)

    result = apply

    expect(result).to have_attributes(status: "rejected", reason_code: "stale_preview")
    expect(transaction.reload.description).to eq("Before repair")
    expect(AuditOperation.where(source: :admin_repair)).to be_empty
  end

  it "rolls back the full mutation and its audit history when the applier fails" do
    allow(applier).to receive(:call) do
      transaction.update!(description: "Partial mutation")
      raise ActiveRecord::RecordInvalid, transaction
    end

    result = apply

    expect(result).to have_attributes(status: "rejected", reason_code: "validation_failed")
    expect(transaction.reload.description).to eq("Before repair")
    expect(AuditOperation.where(source: :admin_repair)).to be_empty
    expect(AuditVersion.where(item_type: "CashTransaction", item_id: transaction.id)).to be_empty
  end

  def apply(confirmed: true, token: preview.apply_token)
    described_class.new(
      definition:,
      scope:,
      request_id: "request-123",
      token:,
      confirmed:
    ).call
  end
end
