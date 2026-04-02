# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::MessageBackfillRunner do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:conversation) { Conversation.create_with_participants!(sender, receiver) }
    let(:reference_transaction) do
      create(:cash_transaction, user: sender, user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random)))
    end

    before do
      conversation.messages.create!(user: sender, body: "hello")
      conversation.messages.create!(
        user: sender,
        reference_transactable: reference_transaction,
        body: "Notification",
        headers: { id: reference_transaction.id, type: "CashTransaction" }.to_json
      )
      conversation.messages.create!(
        user: sender,
        reference_transactable: reference_transaction,
        body: "Destroyed"
      )
    end

    it "moves human and assistant messages into distinct conversation kinds" do
      result = described_class.new(dry_run: false).call

      expect(result[:moved_messages_count]).to eq(2)
      expect(result[:rewritten_messages_count]).to eq(2)

      human_message = Message.find_by(body: "hello")
      notification_message = Message.where(reference_transactable: reference_transaction)
                                    .where("headers LIKE ?", "%message_notification_v2%")
                                    .find_by(body: "notification:create")
      destroy_message = Message.where(reference_transactable: reference_transaction).find_by(body: "notification:destroy")

      expect(human_message.conversation.kind).to eq("human")
      expect(notification_message.conversation.kind).to eq("assistant")
      expect(JSON.parse(notification_message.headers)).to include("version" => "message_notification_v2")
      expect(JSON.parse(notification_message.headers).dig("event", "action")).to eq("create")
      expect(destroy_message.conversation.kind).to eq("assistant")
      expect(destroy_message.conversation).to eq(notification_message.conversation)
      expect(JSON.parse(destroy_message.headers).dig("event", "action")).to eq("destroy")
    end

    it "preserves the source conversation scenario when rebuilding target conversations" do
      scenario_conversation = Conversation.create_with_participants!(sender, receiver, scenario_key: "scenario-1")
      scenario_conversation.messages.create!(user: sender, body: "hello from scenario")

      result = described_class.new(dry_run: false).call

      moved_message = Message.find_by(body: "hello from scenario")

      expect(result[:moved_messages_count]).to be >= 1
      expect(moved_message.conversation.kind).to eq("human")
      expect(moved_message.conversation.scenario_key).to eq("scenario-1")
    end

    it "groups legacy notifications by canonical chain root when rewriting create vs update" do
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      sender_entity_for_receiver = create(:entity, user: sender, entity_name: "GIGI", entity_user: receiver)
      receiver_entity_for_sender = create(:entity, user: receiver, entity_name: "RIKKI", entity_user: sender)

      source_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Backfill grouping source",
        price: -5_000,
        date: Date.new(2026, 3, 24),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity_for_receiver.id, is_payer: true, price: -5_000, price_to_be_returned: -5_000 } ],
        cash_installments_attributes: [ { number: 1, price: -5_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 } ]
      )
      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: source_transaction,
        description: "Backfill grouping sender return",
        price: -5_000,
        date: Date.new(2026, 3, 25),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity_for_receiver.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, price: -5_000, date: Date.new(2026, 3, 25), month: 3, year: 2026 } ]
      )
      create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Backfill grouping receiver return",
        price: 5_000,
        date: Date.new(2026, 3, 25),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity_for_sender.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, price: 5_000, date: Date.new(2026, 3, 25), month: 3, year: 2026 } ]
      )

      legacy_conversation = Conversation.create_with_participants!(sender, receiver)
      create_message = legacy_conversation.messages.create!(
        user: sender,
        reference_transactable: source_transaction,
        body: "Legacy create",
        headers: { id: source_transaction.id, type: "CashTransaction" }.to_json,
        created_at: 2.minutes.ago
      )
      update_message = legacy_conversation.messages.create!(
        user: sender,
        reference_transactable: sender_shared_return,
        body: "Legacy update",
        headers: { id: sender_shared_return.id, type: "CashTransaction" }.to_json,
        created_at: 1.minute.ago
      )

      described_class.new(dry_run: false).call

      rewritten_messages = Message.where(id: [ create_message.id, update_message.id ]).order(:created_at)

      expect(rewritten_messages.pluck(:body)).to include("notification:create", "notification:update")
      expect(JSON.parse(rewritten_messages.last.headers).dig("event", "action")).to eq("update")
    end

    it "rewrites legacy destroy messages to the surviving sender-side parent when available" do
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      sender_entity_for_receiver = create(:entity, user: sender, entity_name: "GIGI", entity_user: receiver)
      receiver_entity_for_sender = create(:entity, user: receiver, entity_name: "RIKKI", entity_user: sender)

      source_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Backfill destroy source",
        price: -5_000,
        date: Date.new(2026, 3, 24),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity_for_receiver.id, is_payer: true, price: -5_000, price_to_be_returned: -5_000 } ],
        cash_installments_attributes: [ { number: 1, price: -5_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 } ]
      )
      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: source_transaction,
        description: "Backfill destroy sender return",
        price: -5_000,
        date: Date.new(2026, 3, 25),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity_for_receiver.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, price: -5_000, date: Date.new(2026, 3, 25), month: 3, year: 2026 } ]
      )
      receiver_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Backfill destroy receiver return",
        price: 5_000,
        date: Date.new(2026, 3, 25),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity_for_sender.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, price: 5_000, date: Date.new(2026, 3, 25), month: 3, year: 2026 } ]
      )

      legacy_conversation = Conversation.create_with_participants!(sender, receiver)
      legacy_destroy_message = legacy_conversation.messages.create!(
        user: sender,
        reference_transactable: receiver_borrow_return,
        body: "Destroyed"
      )

      result = described_class.new(dry_run: false).call

      legacy_destroy_message.reload

      expect(legacy_destroy_message.body).to eq("notification:destroy")
      expect(legacy_destroy_message.reference_transactable).to eq(sender_shared_return)
      expect(JSON.parse(legacy_destroy_message.headers).dig("event", "action")).to eq("destroy")
      expect(JSON.parse(legacy_destroy_message.headers).dig("event", "details", "price")).to eq(receiver_borrow_return.price)
      expect(result[:rewrites]).to include(a_hash_including(message_id: legacy_destroy_message.id, reference_rewritten: true))
    end
  end
end
