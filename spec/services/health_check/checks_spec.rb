# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health check diagnostic adapters" do
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { admin.main_context }
  let(:scope) { HealthCheck::Scope.new(user: admin, context:) }

  it "returns the same healthy result contract when every audit has zero rows" do
    stub_empty_audits

    results = HealthCheck::Registry.entries.map { |entry| entry.runner.new(scope: scope.for_entry(entry)).call }

    expect(results.map(&:check_key)).to eq(HealthCheck::Registry.keys)
    expect(results).to all(be_healthy)
    expect(results.map(&:counts)).to all(eq(empty_counts))
    expect(results).to all(have_attributes(error_code: nil, severity: "error"))
  end

  it "normalizes Exchange Trio failures and supported canonical repairs with explicit scope" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    relationship_scope = HealthCheck::Scope.new(user: admin, context:, connected_user:)
    row = {
      status: "pending",
      issues: [ "middle_reference_mismatch" ],
      warnings: [],
      proposed_changes: [ { action: "set_reference" } ]
    }
    audit = instance_double(Logic::ExchangeTrioAudit, call: [ row ])
    projector = instance_double(Logic::ExchangeAuditSelectionProjector, call: [ row ])
    reference_audit = instance_double(
      Logic::ExchangeChainReferenceAudit,
      call: { supported_count: 1, skipped_count: 0, candidates: [ { supported: true } ] }
    )

    expect(Logic::ExchangeTrioAudit).to receive(:new).with(
      current_user: admin,
      current_context: context,
      connected_user_id: connected_user.id
    ).and_return(audit)
    expect(Logic::ExchangeAuditSelectionProjector).to receive(:new).with(rows: [ row ]).and_return(projector)
    expect(Logic::ExchangeChainReferenceAudit).to receive(:new).with(rows: [ row ]).and_return(reference_audit)

    result = HealthCheck::Checks::ExchangeTrio.new(scope: relationship_scope).call

    expect(result).to be_failing
    expect(result.counts).to include(
      "affected" => 1,
      "failures" => 1,
      "repairable" => 1,
      "read_only" => 0,
      "unavailable_actions" => 0
    )
  end

  it "keeps safe pending Exchange Return allocations repairable and paid findings read-only" do
    pending_row = {
      paid: false,
      issues: [ "source_allocation_mismatch" ],
      source_allocation_rows: [
        {
          entity_transaction_id: 12,
          issue_code: "missing_moi_allocation",
          calculated_loan_return_percentage: 50,
          calculated_price: -500
        }
      ]
    }
    paid_row = { paid: true, issues: [ "installments_total_mismatch" ], source_allocation_rows: [] }
    stub_status_audit(Logic::ExchangeReturnAudit, pending: [ pending_row ], paid: [ paid_row ])

    result = HealthCheck::Checks::ExchangeReturn.new(scope:).call

    expect(result).to be_failing
    expect(result.counts).to include(
      "affected" => 2,
      "failures" => 2,
      "warnings" => 1,
      "repairable" => 1,
      "read_only" => 1,
      "unavailable_actions" => 1
    )
  end

  it "reports Card Projection warning-only rows as warning" do
    warning_row = {
      paid: false,
      issues: [],
      warnings: [ "projection_shape_mismatch" ],
      expected_rows: [],
      actual_rows: []
    }
    stub_status_audit(Logic::CardExchangeProjectionAudit, pending: [ warning_row ], paid: [])

    result = HealthCheck::Checks::CardExchangeProjection.new(scope:).call

    expect(result).to be_warning
    expect(result.severity).to eq("warning")
    expect(result.counts).to include("affected" => 1, "failures" => 0, "warnings" => 1, "read_only" => 1)
  end

  it "lets Card Projection failures win over warnings" do
    mixed_row = {
      paid: false,
      issues: [ "payer_exchange_total_mismatch" ],
      warnings: [ "projection_shape_mismatch" ],
      expected_rows: [],
      actual_rows: []
    }
    stub_status_audit(Logic::CardExchangeProjectionAudit, pending: [ mixed_row ], paid: [])

    result = HealthCheck::Checks::CardExchangeProjection.new(scope:).call

    expect(result).to be_failing
    expect(result.severity).to eq("error")
    expect(result.counts).to include("failures" => 1, "warnings" => 1)
  end

  it "only exposes an unambiguous, unpaid Card Projection target as repairable" do
    source = create(:card_transaction, user: admin, context:)
    source_entity = source.entity_transactions.first
    source_entity.update!(is_payer: true, price: source.price, price_to_be_returned: source.price)
    exchange = create(
      :exchange,
      entity_transaction: source_entity,
      exchange_type: :monetary,
      bound_type: :card_bound,
      price: source.price,
      number: 1,
      month: source.month,
      year: source.year
    )
    target = exchange.reload.cash_transaction
    row = {
      paid: false,
      expected_rows: [ { number: 1, month: (target.month % 12) + 1, year: target.year } ],
      actual_rows: [
        {
          cash_transaction_id: target.id,
          number: exchange.number,
          month: exchange.month,
          year: exchange.year,
          price: exchange.price
        }
      ]
    }
    adapter = HealthCheck::Checks::CardExchangeProjection.new(scope:)

    expect(target.reload).to be_exchange_return
    expect(target.cash_installments).to all(satisfy { |installment| !installment.paid? })
    expect(target.exchanges.card_bound.monetary).to exist
    expect(adapter.send(:repairable_projection?, row)).to be(true)

    target.cash_installments.first.update!(paid: true)

    expect(adapter.send(:repairable_projection?, row)).to be(false)
  end

  it "counts misplaced sources and messages while keeping connected-user sources read-only" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    relationship_scope = HealthCheck::Scope.new(user: admin, context:, connected_user:)
    audit = instance_double(
      Logic::MisplacedLoanExchangeAudit,
      call: [
        { source_user_id: admin.id, message_ids: [ 11, 12 ] },
        { source_user_id: connected_user.id, message_ids: [ 13 ] }
      ]
    )

    expect(Logic::MisplacedLoanExchangeAudit).to receive(:new).with(
      current_user: admin,
      current_context: context,
      connected_user_id: connected_user.id
    ).and_return(audit)

    result = HealthCheck::Checks::MisplacedExchangeIntent.new(scope: relationship_scope).call

    expect(result).to be_failing
    expect(result.counts).to include(
      "affected" => 5,
      "failures" => 2,
      "repairable" => 1,
      "read_only" => 1,
      "unavailable_actions" => 1
    )
  end

  it "keeps every Piggy Bank finding diagnostic-only" do
    audit = instance_double(Logic::PiggyBankAudit, call: [ { issues: %w[missing_return entity_mismatch] } ])
    expect(Logic::PiggyBankAudit).to receive(:new).with(current_user: admin, current_context: context).and_return(audit)

    result = HealthCheck::Checks::PiggyBank.new(scope:).call

    expect(result).to be_failing
    expect(result.counts).to include(
      "affected" => 1,
      "failures" => 2,
      "repairable" => 0,
      "read_only" => 1,
      "unavailable_actions" => 1
    )
  end

  def stub_empty_audits
    exchange_trio = instance_double(Logic::ExchangeTrioAudit, call: [])
    projector = instance_double(Logic::ExchangeAuditSelectionProjector, call: [])
    reference_audit = instance_double(Logic::ExchangeChainReferenceAudit, call: { supported_count: 0, skipped_count: 0, candidates: [] })

    allow(Logic::ExchangeTrioAudit).to receive(:new).and_return(exchange_trio)
    allow(Logic::ExchangeAuditSelectionProjector).to receive(:new).and_return(projector)
    allow(Logic::ExchangeChainReferenceAudit).to receive(:new).and_return(reference_audit)
    stub_status_audit(Logic::ExchangeReturnAudit, pending: [], paid: [])
    stub_status_audit(Logic::CardExchangeProjectionAudit, pending: [], paid: [])
    allow(Logic::MisplacedLoanExchangeAudit).to receive(:new).and_return(instance_double(Logic::MisplacedLoanExchangeAudit, call: []))
    allow(Logic::PiggyBankAudit).to receive(:new).and_return(instance_double(Logic::PiggyBankAudit, call: []))
  end

  def stub_status_audit(audit_class, pending:, paid:)
    allow(audit_class).to receive(:new) do |status_filter:, **|
      rows = status_filter == "paid" ? paid : pending
      instance_double(audit_class, call: rows)
    end
  end

  def empty_counts
    {
      "affected" => 0,
      "failures" => 0,
      "warnings" => 0,
      "repairable" => 0,
      "read_only" => 0,
      "unavailable_actions" => 0
    }
  end
end
