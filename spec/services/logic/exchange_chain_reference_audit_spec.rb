# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeChainReferenceAudit do
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

      if extra_middle
        create(
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

      origin_cash_transaction
    end

    it "returns supported candidates for unambiguous pending rows" do
      source_transaction = create_pending_reimbursement_case

      result = described_class.new.call
      candidate = result[:candidates].find { |row| row[:source_transaction_id] == source_transaction.id }

      expect(result[:candidate_count]).to eq(1)
      expect(result[:supported_count]).to eq(1)
      expect(candidate).to include(
        source_transaction_id: source_transaction.id,
        chain_kind: "shared_return_chain",
        supported: true
      )
      expect(candidate[:proposed_changes].size).to eq(1)
    end

    it "marks rows with multiple middle candidates as unsupported" do
      result = described_class.new(
        rows: [
          {
            status: "pending",
            message: { id: 77, conversation_id: 12 },
            source: { id: 88 },
            chain_kind: "shared_return_chain",
            end_kind: "shared_return",
            intent: "reimbursement",
            issues: [ "multiple_middle_candidates" ],
            proposed_changes: [
              {
                node_key: "middle",
                transaction: { id: 99, type: "CashTransaction", description: "Middle node", user_id: sender.id },
                from_reference: nil,
                to_reference: { id: 88, type: "CashTransaction" },
                action: "set_reference"
              }
            ]
          }
        ]
      ).call
      candidate = result[:candidates].first

      expect(result[:candidate_count]).to eq(1)
      expect(result[:supported_count]).to eq(0)
      expect(candidate).to include(
        source_transaction_id: 88,
        supported: false,
        unsupported_reason: "multiple_middle_candidates"
      )
    end
  end
end
