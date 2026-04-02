# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeAuditSelectionProjector do
  describe "#call" do
    let(:row) do
      {
        status: "pending",
        receiver: { id: 2, first_name: "Receiver", email: "receiver@example.com" },
        source: { id: 100, type: "CashTransaction", description: "Source", user_id: 1, current_reference: nil, expected_reference: nil, reference_status: "ok" },
        middle: {
          id: 200,
          type: "CashTransaction",
          description: "First middle",
          user_id: 1,
          price: 1_500,
          installment_signature: [ [ 1, 1_500 ] ],
          entity_user_ids: [ 9 ],
          current_reference: nil,
          expected_reference: { id: 100, type: "CashTransaction" },
          reference_status: "missing",
          node_key: "middle"
        },
        middle_candidates: [
          {
            id: 200,
            type: "CashTransaction",
            description: "First middle",
            user_id: 1,
            price: 1_500,
            installment_signature: [ [ 1, 1_500 ] ],
            entity_user_ids: [ 9 ],
            current_reference: nil,
            expected_reference: { id: 100, type: "CashTransaction" },
            reference_status: "missing",
            node_key: "middle_candidate"
          },
          {
            id: 201,
            type: "CashTransaction",
            description: "Second middle",
            user_id: 1,
            price: 1_500,
            installment_signature: [ [ 1, 1_500 ] ],
            entity_user_ids: [ 2 ],
            current_reference: nil,
            expected_reference: { id: 100, type: "CashTransaction" },
            reference_status: "missing",
            node_key: "middle_candidate"
          }
        ],
        receiver_candidates: [
          {
            id: 301,
            type: "CashTransaction",
            description: "Receiver fallback",
            user_id: 2,
            price: -1_500,
            installment_signature: [ [ 1, 1_500 ] ],
            category_names: [ "BORROW RETURN" ],
            entity_names: [ "SENDER" ],
            current_reference: nil,
            expected_reference: { id: 200, type: "CashTransaction" },
            reference_status: "missing",
            node_key: "receiver_candidate"
          }
        ],
        end_kind: "shared_return",
        end_transactions: [
          {
            id: 300,
            type: "CashTransaction",
            description: "Receiver return",
            user_id: 2,
            price: -1_500,
            installment_signature: [ [ 1, 1_500 ] ],
            current_reference: { id: 100, type: "CashTransaction" },
            expected_reference: { id: 200, type: "CashTransaction" },
            reference_status: "mismatch",
            node_key: "receiver_shared_return"
          }
        ],
        issues: %w[multiple_middle_candidates middle_reference_missing receiver_shared_return_reference_mismatch],
        proposed_changes: [
          {
            node_key: "middle",
            transaction: { id: 200, type: "CashTransaction", description: "First middle", user_id: 1 },
            from_reference: nil,
            to_reference: { id: 100, type: "CashTransaction" },
            action: "set_reference"
          },
          {
            node_key: "receiver_shared_return",
            transaction: { id: 300, type: "CashTransaction", description: "Receiver return", user_id: 2 },
            from_reference: { id: 100, type: "CashTransaction" },
            to_reference: { id: 200, type: "CashTransaction" },
            action: "set_reference"
          }
        ]
      }
    end

    it "reprojects the row against the selected middle candidate" do
      result = described_class.new(rows: [ row ], middle_overrides: { 100 => 201 }).call.first

      expect(result[:selected_middle_id]).to eq(201)
      expect(result.dig(:middle, :id)).to eq(201)
      expect(result.dig(:middle, :node_key)).to eq("middle")
      expect(result[:issues]).not_to include("multiple_middle_candidates")
      expect(result.dig(:end_transactions, 0, :expected_reference)).to include(id: 201, type: "CashTransaction")
      expect(result[:proposed_changes]).to include(
        a_hash_including(
          node_key: "middle",
          transaction: a_hash_including(id: 201),
          to_reference: a_hash_including(id: 100, type: "CashTransaction")
        ),
        a_hash_including(
          node_key: "middle_candidate",
          transaction: a_hash_including(id: 200),
          to_reference: a_hash_including(id: 100, type: "CashTransaction")
        ),
        a_hash_including(
          node_key: "receiver_shared_return",
          to_reference: a_hash_including(id: 201, type: "CashTransaction")
        )
      )
    end

    it "auto-selects the friend-entity candidate when there is a unique receiver match" do
      result = described_class.new(rows: [ row ]).call.first

      expect(result[:selected_middle_id]).to eq(201)
      expect(result.dig(:middle, :id)).to eq(201)
      expect(result.dig(:end_transactions, 0, :expected_reference)).to include(id: 201, type: "CashTransaction")
    end

    it "projects a manual receiver-side selection into the end node" do
      row_with_missing_receiver = row.deep_dup
      row_with_missing_receiver[:end_transactions] = [ nil ]
      row_with_missing_receiver[:issues] = [ "missing_receiver_reference" ]
      row_with_missing_receiver[:proposed_changes] = []

      result = described_class.new(
        rows: [ row_with_missing_receiver ],
        middle_overrides: { 100 => 201 },
        receiver_overrides: { 100 => 301 }
      ).call.first

      expect(result[:selected_middle_id]).to eq(201)
      expect(result[:selected_receiver_id]).to eq(301)
      expect(result.dig(:end_transactions, 0, :id)).to eq(301)
      expect(result[:issues]).not_to include("missing_receiver_reference")
      expect(result.dig(:end_transactions, 0, :expected_reference)).to include(id: 201, type: "CashTransaction")
      expect(result[:proposed_changes]).to include(
        a_hash_including(
          node_key: "receiver_shared_return",
          transaction: a_hash_including(id: 301),
          to_reference: a_hash_including(id: 201, type: "CashTransaction")
        )
      )
    end
  end
end
