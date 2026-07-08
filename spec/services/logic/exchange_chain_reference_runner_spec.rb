# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeChainReferenceRunner do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }

    def sender_entity_for(receiver_user)
      sender.entities.find_or_create_by!(entity_name: receiver_user.first_name.upcase) do |entity_record|
        entity_record.entity_user = receiver_user
      end
    end

    def receiver_entity_for(sender_user)
      receiver.entities.find_or_create_by!(entity_name: sender_user.first_name.upcase) do |entity_record|
        entity_record.entity_user = sender_user
      end
    end

    def assistant_conversation
      Conversation.find_or_create_assistant_between!(sender, receiver)
    end

    def build_ambiguous_row(source_transaction:, first_middle:, second_middle:, receiver_borrow_return:) # rubocop:disable Metrics/MethodLength
      {
        status: "pending",
        message: { id: 321, conversation_id: 654, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction" },
        sender: { id: sender.id, first_name: sender.first_name, email: sender.email },
        receiver: { id: receiver.id, first_name: receiver.first_name, email: receiver.email },
        chain_kind: "shared_return_chain",
        source: serialize_transaction_node(source_transaction, node_key: "source", expected_reference: nil),
        middle: serialize_transaction_node(first_middle, node_key: "middle", expected_reference: source_transaction),
        middle_candidates: [
          serialize_transaction_node(first_middle, node_key: "middle_candidate", expected_reference: source_transaction),
          serialize_transaction_node(second_middle, node_key: "middle_candidate", expected_reference: source_transaction)
        ],
        middle_candidates_count: 2,
        end_kind: "shared_return",
        end_transactions: [
          serialize_transaction_node(receiver_borrow_return, node_key: "receiver_shared_return", expected_reference: first_middle)
        ],
        intent: "reimbursement",
        issues: %w[multiple_middle_candidates middle_reference_missing receiver_shared_return_reference_mismatch],
        proposed_changes: [
          {
            node_key: "middle",
            transaction: { id: first_middle.id, type: "CashTransaction", description: first_middle.description, user_id: first_middle.user_id },
            from_reference: nil,
            to_reference: { id: source_transaction.id, type: "CashTransaction" },
            action: "set_reference"
          },
          {
            node_key: "receiver_shared_return",
            transaction: { id: receiver_borrow_return.id, type: "CashTransaction", description: receiver_borrow_return.description,
                           user_id: receiver_borrow_return.user_id },
            from_reference: { id: source_transaction.id, type: "CashTransaction" },
            to_reference: { id: first_middle.id, type: "CashTransaction" },
            action: "set_reference"
          }
        ]
      }
    end

    def build_missing_receiver_row(source_transaction:, middle:, receiver_borrow_return:)
      middle_node = serialize_transaction_node(middle, node_key: "middle", expected_reference: source_transaction)
      receiver_candidate = serialize_transaction_node(receiver_borrow_return, node_key: "receiver_candidate", expected_reference: middle)
      receiver_candidate[:price] = middle_node[:price]
      receiver_candidate[:installment_signature] = middle_node[:installment_signature]

      {
        status: "pending",
        message: { id: 322, conversation_id: 654, actionable: false, action: "create", scenario_key: nil, body: "Created transaction" },
        sender: { id: sender.id, first_name: sender.first_name, email: sender.email },
        receiver: { id: receiver.id, first_name: receiver.first_name, email: receiver.email },
        chain_kind: "shared_return_chain",
        source: serialize_transaction_node(source_transaction, node_key: "source", expected_reference: nil),
        middle: middle_node,
        middle_candidates: [ middle_node.merge(node_key: "middle_candidate") ],
        middle_candidates_count: 1,
        receiver_candidates: [ receiver_candidate ],
        receiver_candidates_count: 1,
        end_kind: "shared_return",
        end_transactions: [ nil ],
        intent: "reimbursement",
        issues: [ "missing_receiver_reference" ],
        proposed_changes: []
      }
    end

    def serialize_transaction_node(transaction, node_key:, expected_reference:)
      {
        id: transaction.id,
        type: transaction.class.name,
        node_key:,
        user_id: transaction.user_id,
        context_id: transaction.context_id,
        description: transaction.description,
        price: transaction.price,
        date: transaction.date,
        month_year: transaction.month_year,
        category_names: transaction.categories.pluck(:category_name),
        entity_names: transaction.entities.order(:entity_name).pluck(:entity_name),
        installment_signature: transaction.cash_installments.order(:number, :date).map { |installment| [ installment.number, installment.price.abs ] },
        current_reference: serialize_reference(transaction.reference_transactable),
        expected_reference: serialize_reference(expected_reference),
        reference_status: reference_status_for(
          current_reference: serialize_reference(transaction.reference_transactable),
          expected_reference: serialize_reference(expected_reference)
        )
      }
    end

    def serialize_reference(transaction)
      return if transaction.blank?

      { id: transaction.id, type: transaction.class.name }
    end

    def reference_status_for(current_reference:, expected_reference:)
      return "ok" if current_reference.blank? && expected_reference.blank?
      return "unexpected" if current_reference.present? && expected_reference.blank?
      return "missing" if current_reference.blank? && expected_reference.present?
      return "ok" if current_reference == expected_reference

      "mismatch"
    end

    def create_pending_reimbursement_case(extra_middle: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      sender_entity = sender_entity_for(receiver)
      receiver_entity = receiver_entity_for(sender)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

      origin_cash_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Reimbursement source",
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        price: -2_000,
        friend_notification_intent: "reimbursement",
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -2_000, price_to_be_returned: -2_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -2_000, paid: false } ]
      )

      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Reimbursement return",
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        price: -2_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false },
          { number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false }
        ]
      )

      payer_entity_transaction = origin_cash_transaction.entity_transactions.first
      create(
        :exchange,
        entity_transaction: payer_entity_transaction,
        cash_transaction: sender_shared_return,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -1_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )

      extra_sender_shared_return = nil

      if extra_middle
        extra_sender_shared_return = create(
          :cash_transaction,
          user: sender,
          context: sender.main_context,
          user_bank_account: sender_bank_account,
          description: "Secondary return",
          date: Date.new(2026, 4, 20),
          month: 4,
          year: 2026,
          price: -1_000,
          category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
          entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
          cash_installments_attributes: [ { number: 1, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false } ]
        ).tap do |second_shared_return|
          create(
            :exchange,
            entity_transaction: payer_entity_transaction,
            cash_transaction: second_shared_return,
            bound_type: :standalone,
            exchange_type: :monetary,
            number: 2,
            price: -1_000,
            date: Date.new(2026, 4, 20),
            month: 4,
            year: 2026
          )
        end
      end

      receiver_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: origin_cash_transaction,
        description: sender_shared_return.description,
        date: sender_shared_return.date,
        month: sender_shared_return.month,
        year: sender_shared_return.year,
        price: sender_shared_return.price,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: sender_shared_return.cash_installments.order(:number).map do |installment|
          { number: installment.number, date: installment.date, month: installment.month, year: installment.year, price: installment.price, paid: installment.paid }
        end
      )

      assistant_conversation.messages.create!(
        user: sender,
        reference_transactable: origin_cash_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: receiver_borrow_return.description }
          },
          replay: {
            id: origin_cash_transaction.id,
            type: "CashTransaction",
            intent: "reimbursement",
            description: receiver_borrow_return.description,
            price: receiver_borrow_return.price,
            date: receiver_borrow_return.date.iso8601,
            month: receiver_borrow_return.month,
            year: receiver_borrow_return.year
          }
        }.to_json
      )

      [ origin_cash_transaction, sender_shared_return, receiver_borrow_return, extra_sender_shared_return ]
    end

    it "reports edge rewrites during dry run without mutating transactions" do
      source_transaction, sender_shared_return, receiver_borrow_return = create_pending_reimbursement_case

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: true).call

      expect(result[:updated_row_count]).to eq(1)
      expect(result[:updated_change_count]).to eq(1)
      expect(sender_shared_return.reload.reference_transactable).to eq(source_transaction)
      expect(receiver_borrow_return.reload.reference_transactable).to eq(source_transaction)
    end

    it "applies canonical parent references for supported rows" do
      source_transaction, sender_shared_return, receiver_borrow_return = create_pending_reimbursement_case

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: false).call
      row = Logic::ExchangeTrioAudit.new.call.find { |candidate| candidate.dig(:source, :id) == source_transaction.id }

      expect(result[:updated_row_count]).to eq(1)
      expect(result[:skipped_count]).to eq(0)
      expect(sender_shared_return.reload.reference_transactable).to eq(source_transaction)
      expect(receiver_borrow_return.reload.reference_transactable).to eq(sender_shared_return)
      expect(row[:status]).to eq("done")
      expect(row[:proposed_changes]).to be_empty
    end

    it "skips ambiguous rows with multiple middle candidates" do
      source_transaction, sender_shared_return, receiver_borrow_return = create_pending_reimbursement_case
      audit_result = {
        generated_at: Time.current.iso8601,
        candidate_count: 1,
        supported_count: 0,
        skipped_count: 1,
        candidates: [
          {
            message_id: 321,
            conversation_id: 654,
            source_transaction_id: source_transaction.id,
            chain_kind: "shared_return_chain",
            end_kind: "shared_return",
            intent: "reimbursement",
            issues: [ "multiple_middle_candidates" ],
            proposed_changes: [],
            supported: false,
            unsupported_reason: "multiple_middle_candidates"
          }
        ]
      }

      allow(Logic::ExchangeChainReferenceAudit).to receive(:new).and_return(instance_double(Logic::ExchangeChainReferenceAudit, call: audit_result))

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: false).call

      expect(result[:updated_row_count]).to eq(0)
      expect(result[:skipped]).to include(
        a_hash_including(
          source_transaction_id: source_transaction.id,
          reason: "multiple_middle_candidates"
        )
      )
      expect(sender_shared_return.reload.reference_transactable).to eq(source_transaction)
      expect(receiver_borrow_return.reload.reference_transactable).to eq(source_transaction)
    end

    it "applies a selected middle candidate and the refreshed projected row becomes done" do
      source_transaction, first_middle, receiver_borrow_return, second_middle = create_pending_reimbursement_case(extra_middle: true)
      projected_rows = Logic::ExchangeAuditSelectionProjector.new(
        rows: [ build_ambiguous_row(source_transaction:, first_middle:, second_middle:, receiver_borrow_return:) ],
        middle_overrides: { source_transaction.id => second_middle.id }
      ).call

      result = described_class.new(rows: projected_rows, source_transaction_ids: [ source_transaction.id ], dry_run: false).call
      refreshed_rows = Logic::ExchangeAuditSelectionProjector.new(
        rows: [ build_ambiguous_row(source_transaction:, first_middle: first_middle.reload, second_middle: second_middle.reload,
                                    receiver_borrow_return: receiver_borrow_return.reload) ],
        middle_overrides: { source_transaction.id => second_middle.id }
      ).call

      expect(result[:updated_row_count]).to eq(1)
      expect(result[:updated_change_count]).to eq(2)
      expect(first_middle.reload.reference_transactable).to eq(source_transaction)
      expect(second_middle.reload.reference_transactable).to eq(source_transaction)
      expect(receiver_borrow_return.reload.reference_transactable).to eq(second_middle)
      expect(refreshed_rows.first[:status]).to eq("done")
      expect(refreshed_rows.first[:proposed_changes]).to be_empty
    end

    it "applies a selected receiver-side candidate when the local transaction is missing from the row" do
      source_transaction, middle, receiver_borrow_return = create_pending_reimbursement_case
      receiver_borrow_return.update_columns(reference_transactable_type: nil, reference_transactable_id: nil)
      receiver_borrow_return.reload

      projected_rows = Logic::ExchangeAuditSelectionProjector.new(
        rows: [ build_missing_receiver_row(source_transaction:, middle:, receiver_borrow_return:) ],
        receiver_overrides: { source_transaction.id => receiver_borrow_return.id }
      ).call

      result = described_class.new(rows: projected_rows, source_transaction_ids: [ source_transaction.id ], dry_run: false).call

      expect(result[:updated_row_count]).to eq(1)
      expect(result[:updated_change_count]).to eq(1)
      expect(receiver_borrow_return.reload.reference_transactable).to eq(middle)
    end
  end
end
