# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBankReconciliations::Apply do
  let(:user) { create(:user, :random) }
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

  def preview(observed_net_cents: 5_500, observed_on: "2026-09-15", target: return_transaction, preview_context: context)
    PiggyBankReconciliations::Preview.new(
      user:,
      context: preview_context,
      return_cash_transaction_id: target&.id,
      observed_net_cents:,
      observed_on:
    ).call
  end

  def apply(plan: nil, observed_net_cents: 5_500, observed_on: "2026-09-15", digest: nil, target: return_transaction, apply_context: context, description: nil,
            request_id: nil)
    if plan
      described_class.from_plan(plan, digest: digest || plan.digest, description:, request_id:).call
    else
      resolved_digest = digest
      if resolved_digest.nil?
        p = preview(observed_net_cents:, observed_on:, target:, preview_context: apply_context)
        resolved_digest = p.digest
      end

      described_class.new(
        user:,
        context: apply_context,
        return_cash_transaction_id: target&.id,
        observed_net_cents:,
        observed_on:,
        digest: resolved_digest,
        description:,
        request_id:
      ).call
    end
  end

  it "applies a positive reconciliation delta atomically and synchronizes the return projection" do
    initial_plan = preview(observed_net_cents: 5_500)
    result = nil

    expect do
      result = apply(plan: initial_plan, description: "September net check")
    end.to change(Investment, :count).by(1)
       .and change(AuditOperation, :count).by(1)

    expect(result).to be_applied
    expect(result).to be_success
    expect(result).to be_valid
    expect(result.reason_code).to be_nil
    expect(result.delta_cents).to eq(500)

    investment = result.investment
    expect(investment).to have_attributes(
      user_id: user.id,
      context_id: context.id,
      user_bank_account_id: account.id,
      investment_type_id: investment_type.id,
      piggy_bank_return_cash_transaction_id: return_transaction.id,
      price: 500,
      description: "September net check",
      month: 9,
      year: 2026
    )
    expect(investment.date.to_date).to eq(Date.new(2026, 9, 15))

    reloaded_return = return_transaction.reload
    expect(reloaded_return).to have_attributes(
      price: 5_500,
      starting_price: 5_500,
      paid: false
    )
    expect(reloaded_return.cash_installments.sole).to have_attributes(
      price: 5_500,
      starting_price: 5_500,
      paid: false
    )

    expect(result.operation.metadata).to include(
      "operation_kind" => "piggy_bank_net_reconciliation",
      "return_cash_transaction_id" => return_transaction.id,
      "delta_cents" => 500,
      "preview_digest" => initial_plan.digest
    )
  end

  it "uses the default description when none is provided" do
    result = apply(observed_net_cents: 5_300)

    expect(result).to be_applied
    expect(result.investment.description).to eq("OBSERVED NET RECONCILIATION")
  end

  it "uses the localized default description in Portuguese" do
    result = I18n.with_locale(:"pt-BR") do
      apply(observed_net_cents: 5_300)
    end

    expect(result).to be_applied
    expect(result.investment.description).to eq("RECONCILIAÇÃO LÍQUIDA OBSERVADA")
  end

  it "applies a negative correction delta and updates unpaid projection" do
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
    expect(return_transaction.reload.price).to eq(5_800)

    result = apply(observed_net_cents: 5_300)

    expect(result).to be_applied
    expect(result.delta_cents).to eq(-500)
    expect(result.investment.price).to eq(-500)
    expect(return_transaction.reload.price).to eq(5_300)
    expect(return_transaction.cash_installments.sole.price).to eq(5_300)
  end

  it "returns a successful no-op when observed value already matches recorded remaining value" do
    plan = preview(observed_net_cents: 5_000)
    result = nil

    expect do
      result = apply(plan:)
    end.not_to(change { [ Investment.count, AuditOperation.count, AuditVersion.count, return_transaction.reload.updated_at ] })

    expect(result).to be_noop
    expect(result).to be_success
    expect(result).not_to be_applied
    expect(result.investment).to be_nil
    expect(result.delta_cents).to eq(0)
    expect(result.reason_code).to be_nil
  end

  it "preserves paid return installments and adjusts only the unpaid remainder after partial withdrawal" do
    paid_installment = return_transaction.cash_installments.sole
    paid_installment.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(paid_installment).split_installment(return_transaction.date, 4_000)

    result = apply(observed_net_cents: 4_250)

    expect(result).to be_applied
    expect(result.delta_cents).to eq(250)
    expect(return_transaction.reload.price).to eq(5_250)
    expect(return_transaction.cash_installments.where(paid: true).pluck(:price, :paid)).to eq([ [ 1_000, true ] ])
    expect(return_transaction.cash_installments.where(paid: false).pluck(:price, :paid)).to eq([ [ 4_250, false ] ])
  end

  it "rejects when the preview digest is stale due to an intervening graph mutation" do
    stale_plan = preview(observed_net_cents: 5_500)

    create(
      :investment,
      user:,
      context:,
      user_bank_account: account,
      investment_type:,
      description: "Intervening valuation",
      price: 200,
      date: Date.new(2026, 9, 10),
      month: 9,
      year: 2026,
      piggy_bank_return_cash_transaction: return_transaction
    )

    result = nil
    expect do
      result = apply(plan: stale_plan)
    end.not_to(change { [ Investment.where(price: 500).count, AuditOperation.count ] })

    expect(result).to be_stale
    expect(result.reason_code).to eq(:stale_preview)
    expect(result).not_to be_applied
  end

  it "rejects when digest is blank or mismatched" do
    expect(apply(digest: "")).to have_attributes(status: :stale, reason_code: :stale_preview)
    expect(apply(digest: "bad-digest-token")).to have_attributes(status: :stale, reason_code: :stale_preview)
  end

  it "makes retry or double-submit deterministic by rejecting the second apply with the same digest" do
    plan = preview(observed_net_cents: 5_500)

    first_result = apply(plan:)
    expect(first_result).to be_applied

    second_result = apply(plan:)
    expect(second_result).to be_stale
    expect(second_result.reason_code).to eq(:stale_preview)
    expect(Investment.where(piggy_bank_return_cash_transaction: return_transaction).count).to eq(1)
  end

  it "rejects invalid observation dates and values without database writes" do
    expect(apply(observed_on: "invalid-date", digest: "any")).to have_attributes(status: :invalid, reason_code: :invalid_observation_date)
    expect(apply(observed_net_cents: 0, digest: "any")).to have_attributes(status: :invalid, reason_code: :invalid_observed_value)
    expect(apply(observed_net_cents: -500, digest: "any")).to have_attributes(status: :invalid, reason_code: :invalid_observed_value)
  end

  it "does not mutate returns outside the supplied user and context" do
    other_user = create(:user, :random)
    other_return = create_piggy_bank_return(owner: other_user, transaction_context: other_user.main_context)
    other_context = create(:context, user:)

    expect(apply(target: other_return, digest: "any")).to have_attributes(status: :invalid, reason_code: :return_not_found)
    expect(apply(apply_context: other_context, digest: "any")).to have_attributes(status: :invalid, reason_code: :return_not_found)
  end

  it "rejects ordinary cash transactions and settled Piggy Bank returns" do
    ordinary = create(:cash_transaction, :random, user:, context:, user_bank_account: account)
    expect(apply(target: ordinary, digest: "any")).to have_attributes(status: :invalid, reason_code: :invalid_return)

    return_transaction.cash_installments.update_all(paid: true)
    return_transaction.update_column(:paid, true)
    expect(apply(digest: "any")).to have_attributes(status: :invalid, reason_code: :settled_return)
  end

  it "rejects broken return graphs without writing records" do
    return_transaction.update_column(:price, 5_100)

    result = apply(digest: "any")
    expect(result).to have_attributes(status: :invalid, reason_code: :invalid_return_graph)
    expect(result.issues).to include(:return_total_mismatch)
  end

  it "rejects when investment configuration is missing" do
    allow(InvestmentType).to receive(:find_by).with(investment_type_code: PiggyBankReconciliations::Preview::INVESTMENT_TYPE_CODE).and_return(nil)

    expect(apply(digest: "any")).to have_attributes(status: :invalid, reason_code: :missing_investment_configuration)
  end

  it "restores the entire financial graph and audit history when projection sync fails" do
    initial_price = return_transaction.price
    initial_installment_price = return_transaction.cash_installments.sole.price
    plan = preview(observed_net_cents: 5_500)

    allow_any_instance_of(Investment).to receive(:sync_piggy_bank_return_projection).and_raise(
      ActiveRecord::RecordInvalid.new(return_transaction)
    )

    result = nil
    expect do
      result = apply(plan:)
    end.not_to change(Investment, :count)

    expect(result).to be_failed
    expect(result.reason_code).to eq(:validation_failed)
    expect(return_transaction.reload.price).to eq(initial_price)
    expect(return_transaction.cash_installments.sole.price).to eq(initial_installment_price)
    expect(AuditOperation.where(source: :web, actor_id: user.id)).to be_empty
  end
end
