# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin audit rollback previews", type: :request do
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
        description: "Corrected transaction",
        date: Date.new(2026, 7, 19),
        cash_installments: [ build(:cash_installment, number: 1, paid: false) ]
      )
    end
  end
  let(:operation) { AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id: context.id) }

  before do
    before_state = transaction.attributes.except(*CashTransaction.paper_trail_options.fetch(:skip)).merge("description" => "Original transaction")
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id: context.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: transaction.id,
      event: :update,
      mutation_source: :web,
      object: before_state,
      object_changes: { "description" => [ "Original transaction", transaction.description ] },
      metadata: { "user_bank_account_id" => account.id }
    )
  end

  it "renders an admin-only read-only preview with its digest and signed token" do
    sign_in admin
    version_count = AuditVersion.count
    operation_count = AuditOperation.count

    get admin_audit_operation_rollback_preview_path(operation)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("audit_rollback_preview_digest", "audit_rollback_apply_token", "Corrected transaction", "Original transaction")
    expect(AuditVersion.count).to eq(version_count)
    expect(AuditOperation.count).to eq(operation_count)
    expect(transaction.reload.description).to eq("Corrected transaction")
  end

  it "shows the preview control to admins on operation detail" do
    sign_in admin

    get audit_operation_path(operation)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(admin_audit_operation_rollback_preview_path(operation))
  end

  it "applies a current preview and redirects to the committed rollback operation" do
    sign_in admin
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect do
      post admin_audit_operation_rollback_preview_path(operation), params: { apply_token: preview.apply_token }
    end.to change { AuditOperation.where(source: :rollback, result: :committed).count }.by(1)

    rollback_operation = AuditOperation.where(source: :rollback, result: :committed).order(:created_at).last
    expect(response).to redirect_to(audit_operation_path(rollback_operation))
    expect(rollback_operation).to have_attributes(actor_id: admin.id, rollback_of_operation_id: operation.id)
    expect(transaction.reload.description).to eq("Original transaction")
  end

  it "hides controls and endpoint discovery from ordinary users while recording the rejection" do
    sign_in user

    get audit_operation_path(operation)
    expect(response.body).not_to include(admin_audit_operation_rollback_preview_path(operation))

    version_count = AuditVersion.count
    expect do
      get admin_audit_operation_rollback_preview_path(operation)
    end.to change { AuditOperation.where(source: :rollback, result: :rejected).count }.by(1)

    expect(response).to have_http_status(:not_found)
    expect(AuditVersion.count).to eq(version_count)
    rejection = AuditOperation.where(source: :rollback, result: :rejected).order(:created_at).last
    expect(rejection).to have_attributes(actor_id: user.id, context_id: user.main_context.id, rollback_of_operation_id: nil)
    expect(rejection.metadata).to eq("reason_code" => "authorization_denied")
  end

  it "rejects ordinary-user apply requests without exposing the target operation" do
    sign_in user
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect do
      post admin_audit_operation_rollback_preview_path(operation), params: { apply_token: preview.apply_token }
    end.to change { AuditOperation.where(source: :rollback, result: :rejected).count }.by(1)

    expect(response).to have_http_status(:not_found)
    expect(transaction.reload.description).to eq("Corrected transaction")
  end

  it "records a bounded rejected operation when an admin selects a missing target" do
    sign_in admin
    missing_id = SecureRandom.uuid

    expect do
      get admin_audit_operation_rollback_preview_path(missing_id)
    end.to change { AuditOperation.where(source: :rollback, result: :rejected).count }.by(1)

    expect(response).to have_http_status(:not_found)
    rejection = AuditOperation.where(source: :rollback, result: :rejected).order(:created_at).last
    expect(rejection.metadata).to eq("reason_code" => "operation_not_found")
  end
end
