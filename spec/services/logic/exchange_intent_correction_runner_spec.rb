# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeIntentCorrectionRunner do
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

    def create_mislabeled_reimbursement_case(intent: "loan") # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -2_000, paid: false } ],
        friend_notification_intent: "loan"
      )
      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: origin_cash_transaction,
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
      create(
        :exchange,
        entity_transaction: payer_entity_transaction,
        cash_transaction: sender_shared_return,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 2,
        price: -1_000,
        date: Date.new(2026, 4, 20),
        month: 4,
        year: 2026
      )

      receiver_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
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

      replay_payload = {
        id: origin_cash_transaction.id,
        type: "CashTransaction",
        description: receiver_borrow_return.description,
        price: receiver_borrow_return.price,
        date: receiver_borrow_return.date.iso8601,
        month: receiver_borrow_return.month,
        year: receiver_borrow_return.year
      }
      replay_payload[:intent] = intent if intent.present?

      message = assistant_conversation.messages.create!(
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
          replay: replay_payload
        }.to_json
      )

      [ message, origin_cash_transaction ]
    end

    it "rewrites the candidate message replay intent to reimbursement" do
      message, source_transaction = create_mislabeled_reimbursement_case

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: false).call

      message.reload
      headers = JSON.parse(message.headers)
      refreshed_source = CashTransaction.find(source_transaction.id)

      expect(result[:updated_messages_count]).to eq(1)
      expect(headers.dig("replay", "intent")).to eq("reimbursement")
      expect(refreshed_source.effective_friend_notification_intent).to eq("reimbursement")
      expect(Logic::ExchangeTrioAudit.new.call.first[:intent]).to eq("reimbursement")
    end

    it "does not mutate message headers during dry run" do
      message, source_transaction = create_mislabeled_reimbursement_case

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: true).call

      expect(result[:updated_messages_count]).to eq(1)
      expect(JSON.parse(message.reload.headers).dig("replay", "intent")).to eq("loan")
    end

    it "adds reimbursement intent when the candidate message had no intent key" do
      message, source_transaction = create_mislabeled_reimbursement_case(intent: nil)

      result = described_class.new(source_transaction_ids: [ source_transaction.id ], dry_run: false).call

      expect(result[:updated_messages_count]).to eq(1)
      expect(JSON.parse(message.reload.headers).dig("replay", "intent")).to eq("reimbursement")
    end
  end
end
