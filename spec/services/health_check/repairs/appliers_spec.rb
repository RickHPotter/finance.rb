# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check repair appliers" do
  let(:admin) { create(:user, :random, admin: true) }
  let(:scope) { HealthCheck::Scope.new(user: admin, context: admin.main_context) }

  it "delegates canonical references to the existing scoped runner in apply mode" do
    rows = [ { source: { id: 41 } } ]
    preview = instance_double(HealthCheck::Repairs::Preview, finding_id: "41", changes: [ double, double ])
    audit = instance_double(Logic::ExchangeTrioAudit, call: rows)
    projector = instance_double(Logic::ExchangeAuditSelectionProjector, call: rows)
    runner = instance_double(
      Logic::ExchangeChainReferenceRunner,
      call: { updated_change_count: 2, skipped_count: 0 }
    )
    allow(Logic::ExchangeTrioAudit).to receive(:new).and_return(audit)
    allow(Logic::ExchangeAuditSelectionProjector).to receive(:new).with(rows:).and_return(projector)
    expect(Logic::ExchangeChainReferenceRunner).to receive(:new).with(
      rows:,
      source_transaction_ids: [ "41" ],
      dry_run: false
    ).and_return(runner)

    result = HealthCheck::Repairs::CanonicalReferenceApplier.new(scope:, preview:).call

    expect(result).to include(updated_change_count: 2)
  end

  it "applies only previewed allocation attributes and recalculates from the source month" do
    source_date = Time.zone.local(2026, 5, 10)
    source = instance_double(CardTransaction, context_id: scope.context.id, date: source_date)
    entity_transaction = instance_double(EntityTransaction, transactable: source)
    relation = double(find: entity_transaction)
    allow(EntityTransaction).to receive(:includes).with(:transactable).and_return(relation)
    changes = [
      HealthCheck::Repairs::Change.new(
        record_type: "EntityTransaction",
        record_id: 31,
        attribute: "loan_return_percentage",
        before: 25,
        after: 50
      )
    ]
    preview = instance_double(HealthCheck::Repairs::Preview, finding_id: "31", changes:)
    repair = instance_double(Logic::ExchangeReturnAllocationRepair, call: entity_transaction)
    expect(Logic::ExchangeReturnAllocationRepair).to receive(:new).with(
      entity_transaction:,
      attributes: { "loan_return_percentage" => 50 }
    ).and_return(repair)
    recalculator = instance_double(Logic::RecalculateBalancesService, call: true)
    expect(Logic::RecalculateBalancesService).to receive(:new).with(
      user: admin,
      context: scope.context,
      year: 2026,
      month: 5
    ).and_return(recalculator)

    HealthCheck::Repairs::ExchangeReturnAllocationApplier.new(scope:, preview:).call
  end

  it "delegates owned intent conversion with exactly the previewed active messages" do
    source = instance_double(CashTransaction)
    cash_scope = double(find: source)
    allow(scope.context).to receive(:cash_transactions).and_return(cash_scope)
    preview = instance_double(
      HealthCheck::Repairs::Preview,
      finding_id: "51",
      references: [
        {
          "type" => "Message",
          "ids" => [ 71, 72 ],
          "role" => "active_replay_messages"
        }
      ]
    )
    repair = instance_double(Logic::MisplacedExchangeIntentRepair, call: { source_id: 51, updated_message_count: 2 })
    expect(Logic::MisplacedExchangeIntentRepair).to receive(:new).with(
      source:,
      message_ids: [ 71, 72 ]
    ).and_return(repair)

    result = HealthCheck::Repairs::MisplacedExchangeIntentApplier.new(scope:, preview:).call

    expect(result).to include(updated_message_count: 2)
  end

  it "uses the extracted card repair service and recalculates the repaired date range" do
    original_date = Time.zone.local(2026, 4, 10)
    repaired_date = Time.zone.local(2026, 3, 10)
    target = instance_double(CashTransaction, date: original_date)
    repaired = instance_double(CashTransaction, date: repaired_date)
    cash_scope = double(find: target)
    allow(scope.context).to receive(:cash_transactions).and_return(cash_scope)
    preview = instance_double(
      HealthCheck::Repairs::Preview,
      references: [
        {
          "type" => "CashTransaction",
          "id" => 81,
          "ids" => [ 81 ],
          "role" => "projection_target"
        }
      ]
    )
    repair = instance_double(Logic::CardExchangeProjectionRepair, fixable?: true, call: repaired)
    expect(Logic::CardExchangeProjectionRepair).to receive(:new).with(
      current_user: admin,
      current_context: scope.context,
      cash_transaction: target
    ).and_return(repair)
    recalculator = instance_double(Logic::RecalculateBalancesService, call: true)
    expect(Logic::RecalculateBalancesService).to receive(:new).with(
      user: admin,
      context: scope.context,
      year: 2026,
      month: 3
    ).and_return(recalculator)

    expect(HealthCheck::Repairs::CardExchangeProjectionApplier.new(scope:, preview:).call).to eq(repaired)
  end
end
