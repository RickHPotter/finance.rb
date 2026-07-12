# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeTrioAudit do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:service) { described_class.new }

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

    def create_card_origin_case # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      sender_entity = sender_entity_for(receiver)
      receiver_entity = receiver_entity_for(sender)
      sender_user_card = create(:user_card, :random, user: sender, card: create(:card, :random, bank: create(:bank, :random)))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

      origin_card_transaction = create(
        :card_transaction,
        user: sender,
        context: sender.main_context,
        user_card: sender_user_card,
        description: "Card mirror source",
        date: Date.new(2026, 3, 15),
        month: 4,
        year: 2026,
        price: -2_000
      )
      origin_card_transaction.category_transactions.destroy_all
      origin_card_transaction.category_transactions.create!(category: sender.built_in_category("EXCHANGE"))
      payer_entity_transaction = origin_card_transaction.entity_transactions.first
      payer_entity_transaction.update!(
        entity_id: sender_entity.id,
        is_payer: true,
        price: -2_000,
        price_to_be_returned: -2_000,
        exchanges_count: 2
      )

      first_exchange = create(
        :exchange,
        entity_transaction: payer_entity_transaction,
        bound_type: :card_bound,
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
        bound_type: :card_bound,
        exchange_type: :monetary,
        number: 2,
        price: -1_000,
        date: Date.new(2026, 4, 20),
        month: 4,
        year: 2026
      )

      sender_shared_return = first_exchange.cash_transaction.reload
      receiver_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: origin_card_transaction,
        description: sender_shared_return.description,
        date: sender_shared_return.date,
        month: sender_shared_return.month,
        year: sender_shared_return.year,
        price: sender_shared_return.price,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: sender_shared_return.cash_installments.order(:number).map do |installment|
          { number: installment.number, date: installment.date, month: installment.month, year: installment.year, price: installment.price, paid: installment.paid }
        end
      )

      message = assistant_conversation.messages.create!(
        user: sender,
        reference_transactable: origin_card_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CardTransaction",
            details: { description: receiver_borrow_return.description }
          },
          replay: {
            id: origin_card_transaction.id,
            type: "CardTransaction",
            description: receiver_borrow_return.description,
            price: receiver_borrow_return.price,
            date: receiver_borrow_return.date.iso8601,
            month: receiver_borrow_return.month,
            year: receiver_borrow_return.year,
            cash_installments_attributes: receiver_borrow_return.cash_installments.order(:number).map do |installment|
              { number: installment.number, price: installment.price, paid: installment.paid, date: installment.date.iso8601, month: installment.month,
                year: installment.year }
            end
          }
        }.to_json
      )

      [ message, origin_card_transaction, sender_shared_return, receiver_borrow_return ]
    end

    def create_reimbursement_case(extra_middle: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      sender_entity = sender_entity_for(receiver)
      receiver_entity = receiver_entity_for(sender)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

      origin_cash_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        friend_notification_intent: "reimbursement",
        description: "Reimbursement source",
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        price: -2_000,
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE").id }
        ],
        entity_transactions_attributes: [
          { entity_id: sender_entity.id, is_payer: true, price: -2_000, price_to_be_returned: -2_000 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -2_000, paid: false }
        ]
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
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
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

      extra_sender_shared_return = nil

      if extra_middle
        extra_sender_shared_return = create(
          :cash_transaction,
          user: sender,
          context: sender.main_context,
          user_bank_account: sender_bank_account,
          description: "Reimbursement return alternative",
          date: Date.new(2026, 5, 20),
          month: 5,
          year: 2026,
          price: -2_000,
          category_transactions_attributes: [
            { category_id: sender.built_in_category("EXCHANGE RETURN").id }
          ],
          entity_transactions_attributes: [
            { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
          ],
          cash_installments_attributes: [
            { number: 1, date: Date.new(2026, 5, 20), month: 5, year: 2026, price: -1_000, paid: false },
            { number: 2, date: Date.new(2026, 6, 20), month: 6, year: 2026, price: -1_000, paid: false }
          ]
        )

        create(
          :exchange,
          entity_transaction: payer_entity_transaction,
          cash_transaction: extra_sender_shared_return,
          bound_type: :standalone,
          exchange_type: :monetary,
          number: 3,
          price: -1_000,
          date: Date.new(2026, 5, 20),
          month: 5,
          year: 2026
        )
      end

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
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: sender_shared_return.cash_installments.order(:number).map do |installment|
          { number: installment.number, date: installment.date, month: installment.month, year: installment.year, price: installment.price, paid: installment.paid }
        end
      )

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

      [ message, origin_cash_transaction, sender_shared_return, receiver_borrow_return, extra_sender_shared_return ]
    end

    def create_loan_case # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      sender_entity = sender_entity_for(receiver)
      receiver_entity = receiver_entity_for(sender)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

      origin_cash_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Loan source",
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        price: 5_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 17), month: 3, year: 2026, price: 5_000, paid: false }
        ],
        entity_transactions_attributes: [
          { entity_id: sender_entity.id, is_payer: true, price: -5_000, price_to_be_returned: -5_000, exchanges_count: 1 }
        ]
      )
      payer_entity_transaction = origin_cash_transaction.entity_transactions.first
      first_exchange = create(
        :exchange,
        entity_transaction: payer_entity_transaction,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )
      sender_shared_return = first_exchange.cash_transaction.reload

      receiver_exchange = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: origin_cash_transaction,
        description: "Receiver exchange",
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        price: -5_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, date: Date.new(2026, 3, 17), month: 3, year: 2026, price: -5_000, paid: false }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_entity.id, is_payer: true, price: 5_000, price_to_be_returned: 5_000, exchanges_count: 1 }
        ]
      )
      receiver_payer_entity_transaction = receiver_exchange.entity_transactions.first
      receiver_exchange_record = create(
        :exchange,
        entity_transaction: receiver_payer_entity_transaction,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )
      receiver_exchange_return = receiver_exchange_record.cash_transaction.reload

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
            details: { description: receiver_exchange.description }
          },
          replay: {
            id: origin_cash_transaction.id,
            type: "CashTransaction",
            intent: "loan",
            description: receiver_exchange.description,
            price: receiver_exchange.price,
            date: receiver_exchange.date.iso8601,
            month: receiver_exchange.month,
            year: receiver_exchange.year
          }
        }.to_json
      )

      [ message, origin_cash_transaction, sender_shared_return, receiver_exchange, receiver_exchange_return ]
    end

    it "returns the card-origin trio with a receiver borrow return" do
      _message, source, middle, receiver_end = create_card_origin_case

      row = service.call.find { |result| result.dig(:source, :id) == source.id }

      expect(row).to include(
        chain_kind: "shared_return_chain",
        end_kind: "shared_return",
        intent: nil
      )
      expect(row[:status]).to eq("pending")
      expect(row.dig(:middle, :id)).to eq(middle.id)
      expect(row.dig(:end_transactions, 0, :id)).to eq(receiver_end.id)
      expect(row.dig(:source, :reference_status)).to eq("ok")
      expect(row.dig(:middle, :reference_status)).to eq("missing")
      expect(row.dig(:end_transactions, 0, :reference_status)).to eq("mismatch")
      expect(row.dig(:middle, :expected_reference)).to include(type: "CardTransaction", id: source.id)
      expect(row.dig(:end_transactions, 0, :expected_reference)).to include(type: "CashTransaction", id: middle.id)
      expect(row[:issues]).to include("middle_reference_missing")
      expect(row[:issues]).to include("receiver_shared_return_reference_mismatch")
    end

    it "returns the reimbursement trio with a receiver borrow return" do
      _message, source, middle, receiver_end = create_reimbursement_case

      row = service.call.find { |result| result.dig(:source, :id) == source.id }

      expect(row).to include(
        chain_kind: "shared_return_chain",
        end_kind: "shared_return",
        intent: "reimbursement"
      )
      expect(row[:status]).to eq("done")
      expect(row.dig(:middle, :id)).to eq(middle.id)
      expect(row.dig(:end_transactions, 0, :id)).to eq(receiver_end.id)
      expect(row.dig(:middle, :reference_status)).to eq("ok")
      expect(row.dig(:end_transactions, 0, :reference_status)).to eq("ok")
      expect(row[:proposed_changes]).to be_empty
    end

    it "infers reimbursement intent from an existing receiver borrow return when the message intent is missing" do
      message, source, middle, receiver_end = create_reimbursement_case
      headers = JSON.parse(message.headers)
      headers["replay"].delete("intent")
      message.update!(headers: headers.to_json)

      row = service.call.find do |result|
        result.dig(:source, :id) == source.id && result.dig(:message, :id) == message.id
      end

      expect(row).to include(
        chain_kind: "shared_return_chain",
        end_kind: "shared_return",
        intent: "reimbursement"
      )
      expect(row.dig(:middle, :id)).to eq(middle.id)
      expect(row.dig(:end_transactions, 0, :id)).to eq(receiver_end.id)
    end

    it "returns the loan trio with receiver exchange and receiver exchange return" do
      _message, source, middle, receiver_exchange, receiver_exchange_return = create_loan_case

      row = service.call.find { |result| result.dig(:source, :id) == source.id }

      expect(row).to include(
        chain_kind: "loan_chain",
        end_kind: "loan_receiver_combo",
        intent: "loan"
      )
      expect(row.dig(:middle, :id)).to eq(middle.id)
      expect(row.dig(:end_transactions, 0, :id)).to eq(receiver_exchange.id)
      expect(row.dig(:end_transactions, 1, :id)).to eq(receiver_exchange_return.id)
      expect(row[:status]).to eq("pending")
      expect(row.dig(:end_transactions, 0, :expected_reference)).to include(type: "CashTransaction", id: middle.id)
      expect(row[:issues]).to include("receiver_exchange_reference_mismatch")
    end
  end
end
