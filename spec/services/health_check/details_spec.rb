# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health check detail providers" do
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { admin.main_context }
  let(:scope) { HealthCheck::Scope.new(user: admin, context:) }

  it "pushes Exchange Return status and issue filters into the legacy audit and orders equal dates by stable ID" do
    rows = 30.times.map do |index|
      {
        id: index + 1,
        date: Time.zone.parse("2026-07-20"),
        paid: true,
        issues: [ "installments_total_mismatch" ],
        source_allocation_rows: []
      }
    end
    audit = instance_double(Logic::ExchangeReturnAudit, call: rows)

    expect(Logic::ExchangeReturnAudit).to receive(:new).with(
      current_user: admin,
      current_context: context,
      issue_filter: "installments_total_mismatch",
      status_filter: "paid"
    ).and_return(audit)

    page = HealthCheck::Checks::ExchangeReturnDetails.new(
      scope:,
      filters: { status_filter: "paid", issue_filter: "installments_total_mismatch" }
    ).call

    expect(page).to be_a(HealthCheck::Page)
    expect(page.records.pluck(:id)).to eq((6..30).to_a.reverse)
    expect(page.filters).to include(
      "status_filter" => "paid",
      "issue_filter" => "installments_total_mismatch"
    )
    expect(page.records).to all(include(health_check: include(repairable: false, unavailable_reason: "paid_history")))
  end

  it "normalizes Exchange Trio canonical repair capability with explicit relationship scope" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED", entity_user: connected_user)
    relationship_scope = HealthCheck::Scope.new(user: admin, context:, connected_user:)
    row = {
      status: "pending",
      message: { id: 72, created_at: Time.zone.parse("2026-07-20") },
      source: { id: 91 },
      issues: [ "middle_reference_mismatch" ],
      proposed_changes: [ { action: "set_reference" } ]
    }
    audit = instance_double(Logic::ExchangeTrioAudit, call: [ row ])
    projector = instance_double(Logic::ExchangeAuditSelectionProjector, call: [ row ])
    reference = instance_double(
      Logic::ExchangeChainReferenceAudit,
      call: { candidates: [ { message_id: 72, supported: true, unsupported_reason: nil } ] }
    )

    expect(Logic::ExchangeTrioAudit).to receive(:new).with(
      current_user: admin,
      current_context: context,
      connected_user_id: connected_user.id
    ).and_return(audit)
    expect(Logic::ExchangeAuditSelectionProjector).to receive(:new).with(rows: [ row ]).and_return(projector)
    expect(Logic::ExchangeChainReferenceAudit).to receive(:new).with(rows: [ row ]).and_return(reference)

    page = HealthCheck::Checks::ExchangeTrioDetails.new(scope: relationship_scope).call

    expect(page.records.sole.dig(:health_check, :repairable)).to be(true)
  end

  it "evaluates Piggy Bank only once while filtering diagnostic-only findings" do
    rows = [
      { id: 1, date: Time.zone.today, issues: [ "entity_mismatch" ] },
      { id: 2, date: Time.zone.today, issues: [ "missing_return" ] }
    ]
    audit = instance_double(Logic::PiggyBankAudit, call: rows)
    expect(Logic::PiggyBankAudit).to receive(:new).once.with(current_user: admin, current_context: context).and_return(audit)

    page = HealthCheck::Checks::PiggyBankDetails.new(scope:, filters: { issue_filter: "missing_return" }).call

    expect(page.records.pluck(:id)).to eq([ 2 ])
    expect(page.records.sole[:health_check]).to eq(repairable: false, unavailable_reason: "diagnostic_only")
  end

  it "passes current context and selected connection to misplaced-intent diagnostics" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED", entity_user: connected_user)
    relationship_scope = HealthCheck::Scope.new(user: admin, context:, connected_user:)
    audit = instance_double(Logic::MisplacedLoanExchangeAudit, call: [])

    expect(Logic::MisplacedLoanExchangeAudit).to receive(:new).with(
      current_user: admin,
      current_context: context,
      connected_user_id: connected_user.id
    ).and_return(audit)

    expect(HealthCheck::Checks::MisplacedExchangeIntentDetails.new(scope: relationship_scope).call.records).to be_empty
  end

  it "adds no per-row SQL while normalizing allocation-heavy legacy results" do
    rows = 50.times.map do |index|
      {
        id: index + 1,
        date: Time.zone.today,
        paid: false,
        issues: [ "source_allocation_mismatch" ],
        source_allocation_rows: [
          {
            entity_transaction_id: index + 100,
            issue_code: "missing_moi_allocation",
            calculated_price: 500
          }
        ]
      }
    end
    audit = instance_double(Logic::ExchangeReturnAudit, call: rows)
    allow(Logic::ExchangeReturnAudit).to receive(:new).and_return(audit)
    scope

    query_count = count_sql_queries do
      page = HealthCheck::Checks::ExchangeReturnDetails.new(scope:).call
      expect(page.records.size).to eq(25)
    end

    expect(query_count).to eq(0)
  end

  it "adds no per-row SQL while normalizing reference-heavy legacy results" do
    rows = 50.times.map do |index|
      {
        status: "pending",
        message: { id: index + 1, created_at: Time.zone.today },
        source: { id: index + 100 },
        issues: [ "middle_reference_mismatch" ],
        proposed_changes: [ { action: "set_reference" } ]
      }
    end
    candidates = rows.map do |row|
      { message_id: row.dig(:message, :id), supported: true, unsupported_reason: nil }
    end
    allow(Logic::ExchangeTrioAudit).to receive(:new).and_return(instance_double(Logic::ExchangeTrioAudit, call: rows))
    allow(Logic::ExchangeAuditSelectionProjector).to receive(:new).and_return(instance_double(Logic::ExchangeAuditSelectionProjector, call: rows))
    allow(Logic::ExchangeChainReferenceAudit).to receive(:new).and_return(
      instance_double(Logic::ExchangeChainReferenceAudit, call: { candidates: })
    )
    scope

    query_count = count_sql_queries do
      page = HealthCheck::Checks::ExchangeTrioDetails.new(scope:).call
      expect(page.records.size).to eq(25)
      expect(page.records).to all(include(health_check: include(repairable: true)))
    end

    expect(query_count).to eq(0)
  end

  it "preloads projection repair targets with a bounded query count" do
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
    rows = 20.times.map do |index|
      {
        id: index + 1,
        date: Time.zone.today,
        paid: false,
        issues: [],
        warnings: [ "projection_shape_mismatch" ],
        expected_rows: [ { number: 1, month: (source.month % 12) + 1, year: source.year } ],
        actual_rows: [
          {
            cash_transaction_id: target.id,
            number: 1,
            month: source.month,
            year: source.year,
            price: source.price
          }
        ]
      }
    end
    audit = instance_double(Logic::CardExchangeProjectionAudit, call: rows)
    allow(Logic::CardExchangeProjectionAudit).to receive(:new).and_return(audit)

    query_count = count_sql_queries do
      page = HealthCheck::Checks::CardExchangeProjectionDetails.new(scope:).call
      expect(page.records.size).to eq(20)
      expect(page.records).to all(include(health_check: include(repairable: true)))
    end

    expect(query_count).to be <= 5
  end

  def count_sql_queries(&)
    count = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA CACHE TRANSACTION])
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &)
    count
  end
end
