# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Piggy Bank net reconciliation audit and rollback" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let!(:investment_type) do
    InvestmentType.find_or_create_by!(investment_type_code: PiggyBankReconciliations::Preview::INVESTMENT_TYPE_CODE) do |type|
      type.investment_type_name_fallback = "Other - Piggy Bank"
      type.built_in = true
    end
  end
  let(:return_transaction) { create_piggy_bank_return }

  def create_piggy_bank_return(owner: user, transaction_context: context, price: 5_000)
    owner_account = owner == user ? account : create(:user_bank_account, :random, user: owner)
    owner_entity = owner == user ? entity : create(:entity, :random, user: owner)
    source = build(
      :cash_transaction,
      user: owner,
      context: transaction_context,
      user_bank_account: owner_account,
      description: "Observed reserve",
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Date.new(2026, 9, 1)) ],
      category_transactions: [ CategoryTransaction.new(category: owner.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity: owner_entity, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date: Date.new(2026, 12, 1))
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  def apply_reconciliation(observed_net_cents: 5_500, observed_on: "2026-09-15", target: return_transaction, description: nil)
    plan = PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: target.id,
      observed_net_cents:,
      observed_on:
    ).call

    PiggyBankReconciliations::Apply.new(
      user:,
      context:,
      return_cash_transaction_id: target.id,
      observed_net_cents:,
      observed_on:,
      digest: plan.digest,
      description:
    ).call
  end

  def rollback(operation)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: true
    ).call

    [ preview, result ]
  end

  def canonical_snapshot(transaction)
    transaction.reload
    {
      transaction: transaction.attributes.slice(
        "id", "user_id", "context_id", "user_bank_account_id", "cash_transaction_type",
        "description", "comment", "price", "starting_price", "paid"
      ),
      installments: transaction.cash_installments.order(:id).map do |i|
        i.attributes.slice("id", "number", "price", "starting_price", "paid", "month", "year")
      end,
      investments: transaction.piggy_bank_investments.order(:id).map do |inv|
        inv.attributes.slice("id", "price", "description", "month", "year")
      end,
      links: transaction.piggy_bank_return_links.order(:id).map do |l|
        l.attributes.slice("id", "source_cash_transaction_id", "return_price")
      end
    }
  end

  it "attaches stable scalar metadata and expected mutation sources to the committed AuditOperation" do
    reconcile_result = apply_reconciliation(observed_net_cents: 5_500, description: "Valuation check")
    operation = reconcile_result.operation

    expect(operation).to be_present
    expect(operation.source).to eq("web")
    expect(operation.result).to eq("committed")
    expect(operation.actor_id).to eq(user.id)
    expect(operation.context_id).to eq(context.id)
    expect(operation.metadata).to eq(
      "operation_kind" => "piggy_bank_net_reconciliation",
      "return_cash_transaction_id" => return_transaction.id,
      "context_id" => context.id,
      "user_id" => user.id,
      "observed_on" => "2026-09-15",
      "recorded_remaining_cents" => 5_000,
      "observed_net_cents" => 5_500,
      "delta_cents" => 500,
      "preview_digest" => reconcile_result.digest
    )

    versions = operation.audit_versions.to_a
    expect(versions.pluck(:item_subtype)).to contain_exactly("Investment", "CashTransaction", "CashInstallment")

    investment_version = versions.find { |v| v.item_subtype == "Investment" }
    expect(investment_version).to have_attributes(
      event: "create",
      mutation_source: "web",
      item_id: reconcile_result.investment.id
    )

    transaction_version = versions.find { |v| v.item_subtype == "CashTransaction" }
    expect(transaction_version).to have_attributes(
      event: "update",
      mutation_source: "piggy_bank_sync",
      item_id: return_transaction.id
    )

    installment_version = versions.find { |v| v.item_subtype == "CashInstallment" }
    expect(installment_version).to have_attributes(
      event: "update",
      mutation_source: "piggy_bank_sync",
      item_id: return_transaction.cash_installments.sole.id
    )
  end

  it "restores the exact pre-apply canonical business graph after rolling back a positive reconciliation" do
    before_snapshot = canonical_snapshot(return_transaction)

    reconcile_result = apply_reconciliation(observed_net_cents: 5_500)
    expect(reconcile_result).to be_applied
    created_investment_id = reconcile_result.investment.id

    preview, result = rollback(reconcile_result.operation)

    expect(preview.state).to eq("previewable")
    expect(preview.global_issues).to be_empty
    expect(result.status).to eq("applied")

    expect(Investment).not_to exist(created_investment_id)
    expect(canonical_snapshot(return_transaction)).to eq(before_snapshot)
  end

  it "restores the exact pre-apply canonical business graph after rolling back a negative correction" do
    create(
      :investment,
      user:,
      context:,
      user_bank_account: account,
      investment_type:,
      description: "Previous gross valuation",
      price: 800,
      date: Date.new(2026, 9, 10),
      month: 9,
      year: 2026,
      piggy_bank_return_cash_transaction: return_transaction
    )
    before_snapshot = canonical_snapshot(return_transaction)

    reconcile_result = apply_reconciliation(observed_net_cents: 5_300)
    expect(reconcile_result).to be_applied
    expect(reconcile_result.delta_cents).to eq(-500)

    preview, result = rollback(reconcile_result.operation)

    expect(preview.state).to eq("previewable")
    expect(result.status).to eq("applied")
    expect(canonical_snapshot(return_transaction)).to eq(before_snapshot)
  end

  it "preserves paid return splits and restores the exact pre-apply graph after partial withdrawal" do
    paid_installment = return_transaction.cash_installments.sole
    paid_installment.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(paid_installment).split_installment(return_transaction.date, 4_000)
    before_snapshot = canonical_snapshot(return_transaction)

    reconcile_result = apply_reconciliation(observed_net_cents: 4_250)
    expect(reconcile_result).to be_applied
    expect(reconcile_result.delta_cents).to eq(250)

    preview, result = rollback(reconcile_result.operation)

    expect(preview.state).to eq("previewable")
    expect(result.status).to eq("applied")
    expect(canonical_snapshot(return_transaction)).to eq(before_snapshot)
  end

  it "detects conflicts and blocks rollback when a later mutation edits the reconciled valuation" do
    reconcile_result = apply_reconciliation(observed_net_cents: 5_500)
    reconcile_result.investment.update!(price: 700)

    preview = Audit::Rollback::Preview.new(operation: reconcile_result.operation, actor: admin)

    expect(preview.state).to eq("conflicted")
    investment_row = preview.rows.find { |r| r.record_type == "Investment" }
    expect(investment_row.conflicts).to be_present

    apply_attempt = Audit::Rollback::Apply.new(
      operation: reconcile_result.operation,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: true
    ).call

    expect(apply_attempt.status).to eq("rejected")
    expect(apply_attempt.reason_code).to eq("preview_not_applyable")
    expect(Investment).to exist(reconcile_result.investment.id)
  end

  it "detects conflicts and blocks rollback when a later mutation changes the return transaction" do
    reconcile_result = apply_reconciliation(observed_net_cents: 5_500)
    return_transaction.update_columns(price: 6_000)

    preview = Audit::Rollback::Preview.new(operation: reconcile_result.operation, actor: admin)

    expect(preview.state).to eq("conflicted")
    transaction_row = preview.rows.find { |r| r.record_type == "CashTransaction" }
    expect(transaction_row.conflicts).to be_present
  end

  it "aborts rollback atomically if compensation fails during apply" do
    reconcile_result = apply_reconciliation(observed_net_cents: 5_500)
    post_apply_snapshot = canonical_snapshot(return_transaction)

    preview = Audit::Rollback::Preview.new(operation: reconcile_result.operation, actor: admin)

    allow_any_instance_of(Audit::Rollback::Compensator).to receive(:compensate_transaction_group).and_raise(
      ActiveRecord::RecordInvalid.new(return_transaction)
    )

    apply_attempt = Audit::Rollback::Apply.new(
      operation: reconcile_result.operation,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: true
    ).call

    expect(apply_attempt.status).to eq("rejected")
    expect(apply_attempt.reason_code).to eq("validation_failed")
    expect(canonical_snapshot(return_transaction)).to eq(post_apply_snapshot)
    expect(Investment).to exist(reconcile_result.investment.id)
  end

  it "aborts rollback atomically if integrity verification fails during apply" do
    reconcile_result = apply_reconciliation(observed_net_cents: 5_500)
    post_apply_snapshot = canonical_snapshot(return_transaction)

    preview = Audit::Rollback::Preview.new(operation: reconcile_result.operation, actor: admin)

    allow_any_instance_of(Audit::Rollback::IntegrityVerifier).to receive(:call).and_raise(
      Audit::Rollback::IntegrityVerifier::IntegrityError, "integrity check failed"
    )

    apply_attempt = Audit::Rollback::Apply.new(
      operation: reconcile_result.operation,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: true
    ).call

    expect(apply_attempt.status).to eq("failed")
    expect(apply_attempt.reason_code).to eq("integrity_failed")
    expect(canonical_snapshot(return_transaction)).to eq(post_apply_snapshot)
    expect(Investment).to exist(reconcile_result.investment.id)
  end
end
