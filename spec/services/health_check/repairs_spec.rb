# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check repair previews" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :random, admin: true) }
  let(:scope) { HealthCheck::Scope.new(user: admin, context: admin.main_context) }
  let(:change) do
    HealthCheck::Repairs::Change.new(
      record_type: "CashTransaction",
      record_id: 41,
      attribute: "reference_transactable",
      before: { type: "CashTransaction", id: 12 },
      after: { type: "CashTransaction", id: 13 },
      metadata: { role: "source" }
    )
  end
  let(:result) do
    HealthCheck::Repairs::Result.new(
      finding_id: 41,
      state: "previewable",
      changes: [ change ],
      references: [ { type: "Message", id: 17 } ],
      warnings: [],
      paid_history: { affected: false }
    )
  end

  it "registers exactly the four declared V1 repair planners" do
    definitions = HealthCheck::Repairs::Registry::DEFINITIONS

    expect(definitions.map { |definition| [ definition.check_key, definition.key ] }).to contain_exactly(
      %w[exchange_trio canonical_reference],
      %w[exchange_return source_allocation],
      %w[card_exchange_projection projection],
      %w[misplaced_exchange_intent convert_to_reimbursement]
    )
    expect(HealthCheck::Repairs::Registry.find("piggy_bank", "projection")).to be_nil
    expect(definitions).to all(be_frozen)
    expect(HealthCheck::Registry.fetch("exchange_trio").repair_definitions).to eq(
      [ HealthCheck::Repairs::Registry.fetch("exchange_trio", "canonical_reference") ]
    )
    expect(HealthCheck::Registry.fetch("piggy_bank").repair_definitions).to be_empty
  end

  it "keeps change and result payloads immutable and rejects financial records" do
    expect(change).to be_frozen
    expect(change.before).to be_frozen
    expect(change.metadata).to be_frozen
    expect(result).to be_frozen
    expect(result.changes).to be_frozen
    expect(result.references).to be_frozen
    expect { change.before["id"] = 99 }.to raise_error(FrozenError)
    expect do
      HealthCheck::Repairs::Change.new(
        record_type: "CashTransaction",
        record_id: 1,
        attribute: "context",
        before: admin,
        after: nil
      )
    end.to raise_error(ArgumentError, /financial records/)
  end

  it "produces a deterministic digest and a bounded, expiring signed token" do
    first = build_preview
    second = build_preview
    payload = HealthCheck::Repairs::PreviewToken.verify(first.apply_token)

    expect(first.digest).to eq(second.digest)
    expect(payload).to eq(
      "actor_id" => admin.id,
      "context_id" => admin.main_context.id,
      "connected_user_id" => nil,
      "check_key" => "exchange_trio",
      "repair_key" => "canonical_reference",
      "finding_id" => "41",
      "digest" => first.digest
    )
    expect(payload.to_json).not_to include("reference_transactable", "CashTransaction\":")

    travel HealthCheck::Repairs::PreviewToken::EXPIRES_IN + 1.second
    expect(HealthCheck::Repairs::PreviewToken.verify(first.apply_token)).to be_nil
  end

  it "changes the digest when a relevant current value changes" do
    original = build_preview
    changed_result = HealthCheck::Repairs::Result.new(
      finding_id: 41,
      state: "previewable",
      changes: [
        HealthCheck::Repairs::Change.new(
          record_type: "CashTransaction",
          record_id: 41,
          attribute: "reference_transactable",
          before: { type: "CashTransaction", id: 99 },
          after: { type: "CashTransaction", id: 13 }
        )
      ]
    )

    changed = build_preview(result: changed_result)

    expect(changed.digest).not_to eq(original.digest)
  end

  it "plans canonical reference changes through the existing dry runner without applying them" do
    row = {
      source: { id: 41, type: "CashTransaction", description: "Source" },
      message: { id: 17, conversation_id: 9 }
    }
    audit = instance_double(Logic::ExchangeTrioAudit, call: [ row ])
    projector = instance_double(Logic::ExchangeAuditSelectionProjector, call: [ row ])
    reference = instance_double(
      Logic::ExchangeChainReferenceAudit,
      call: {
        candidates: [
          {
            source_transaction_id: 41,
            message_id: 17,
            conversation_id: 9,
            supported: true,
            issues: [ "source_reference_mismatch" ]
          }
        ]
      }
    )
    runner = instance_double(
      Logic::ExchangeChainReferenceRunner,
      call: {
        updates: [
          {
            applied_changes: [
              {
                node_key: "source",
                transaction: { id: 41, type: "CashTransaction", description: "Source", user_id: admin.id },
                from_reference: { type: "CashTransaction", id: 12 },
                to_reference: { type: "CashTransaction", id: 13 }
              }
            ]
          }
        ]
      }
    )
    allow(Logic::ExchangeTrioAudit).to receive(:new).and_return(audit)
    allow(Logic::ExchangeAuditSelectionProjector).to receive(:new).and_return(projector)
    allow(Logic::ExchangeChainReferenceAudit).to receive(:new).and_return(reference)
    expect(Logic::ExchangeChainReferenceRunner).to receive(:new).with(
      rows: [ row ],
      source_transaction_ids: [ 41 ],
      dry_run: true
    ).and_return(runner)

    planned = HealthCheck::Repairs::CanonicalReferencePlanner.new(scope:, finding_id: 41).call

    expect(planned).to be_previewable
    expect(planned.changes.sole).to have_attributes(record_id: "41", attribute: "reference_transactable")
  end

  it "plans each supported Exchange Return allocation strategy without updating the allocation" do
    allocation = {
      friend_notification_intent: "loan",
      matched_loan_return_percentage: 50,
      calculated_loan_return_percentage: 75,
      calculated_price: 750,
      current_price: 500,
      loan_return_percentage: 25,
      issue_code: "entity_allocation_mismatch"
    }
    entity_transaction = instance_double(
      EntityTransaction,
      id: 31,
      transactable_type: "CardTransaction",
      transactable_id: 22,
      loan_return_percentage: 25.to_d,
      price: 500,
      price_to_be_returned: 500
    )
    planner = HealthCheck::Repairs::ExchangeReturnAllocationPlanner.new(
      scope:,
      finding_id: 31,
      options: { strategy: "corrected_value" }
    )
    allow(planner).to receive_messages(scoped_entity_transaction: entity_transaction, live_allocation: allocation)
    allow(planner).to receive(:audit_rows).and_return([ { id: 7 } ])
    expect(entity_transaction).not_to receive(:update!)

    planned = planner.call

    expect(planned.changes.map(&:attribute)).to contain_exactly("loan_return_percentage", "price", "price_to_be_returned")
    expect(planned.changes.map(&:after)).to contain_exactly(75, 750, 750)
  end

  it "marks ambiguous and paid projection targets read-only with explicit implications" do
    card_transaction = instance_double(CardTransaction, id: 51, paid?: false, card_installments: [])
    row = {
      actual_rows: [
        { cash_transaction_id: 71 },
        { cash_transaction_id: 72 }
      ],
      issues: [ "payer_exchange_total_mismatch" ],
      warnings: []
    }
    planner = HealthCheck::Repairs::CardExchangeProjectionPlanner.new(scope:, finding_id: 51)
    allow(planner).to receive_messages(scoped_card_transaction: card_transaction, live_row: row, projection_target: nil)
    allow(scope.context).to receive(:cash_transactions).and_return(double(find_by: nil))

    planned = planner.call

    expect(planned).not_to be_previewable
    expect(planned.unavailable_reason).to eq("ambiguous_projection")
    expect(planned.paid_history).to eq("affected" => false)
  end

  it "plans the source and active replay intent changes without mutating either record" do
    source = instance_double(
      CashTransaction,
      id: 61,
      friend_notification_intent: "loan",
      effective_friend_notification_intent: "loan"
    )
    row = {
      source_id: 61,
      source_user_id: admin.id,
      message_ids: []
    }
    planner = HealthCheck::Repairs::MisplacedExchangeIntentPlanner.new(scope:, finding_id: 61)
    allow(planner).to receive(:live_row).and_return(row)
    allow(CashTransaction).to receive(:find).with(61).and_return(source)
    expect(source).not_to receive(:update!)

    planned = planner.call

    expect(planned).to be_previewable
    expect(planned.changes.sole).to have_attributes(
      record_type: "CashTransaction",
      attribute: "friend_notification_intent",
      before: "loan",
      after: "reimbursement"
    )
    expect(planned.references.last).to include("count" => 0)
  end

  def build_preview(result: self.result)
    HealthCheck::Repairs::Preview.new(
      check_key: "exchange_trio",
      repair_key: "canonical_reference",
      scope:,
      result:
    )
  end
end
