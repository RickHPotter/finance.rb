# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  describe "[ business logic ]" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:conversation) do
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: sender)
        record.conversation_participants.create!(user: receiver)
      end
    end
    let(:reference_transaction) { create(:cash_transaction, user: sender, user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random))) }

    it "classifies header-bearing messages as transaction notifications" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "Notification",
        headers: { id: reference_transaction.id, type: "CashTransaction" }.to_json
      )

      expect(message.transaction_notification_message?).to be(true)
      expect(message.backfill_kind).to eq("transaction_notification")
    end

    it "renders v2 notification bodies from headers at display time" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "create",
            receiver_first_name: "Gigi",
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "WATER BILL",
              date: "2026-03-17",
              reference_month_year: "MAR <26>",
              price: -5000,
              installments_count: 1,
              installments: [
                { number: 1, date: "2026-03-20", price: -5000 }
              ]
            }
          },
          replay: { id: reference_transaction.id, type: "CashTransaction", intent: "loan" }
        }.to_json
      )

      expect(message.transaction_notification_message?).to be(true)
      expect(message.replay_payload).to include("intent" => "loan")
      expect(message.rendered_body).to include("WATER BILL")
      expect(message.preview_body).to include("WATER BILL")
    end

    it "classifies headerless messages with reference transactable as destroy notifications" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "Destroyed"
      )

      expect(message.transaction_destroy_notification_message?).to be(true)
      expect(message.backfill_kind).to eq("transaction_destroy_notification")
    end

    it "classifies v2 destroy notifications even when headers are present" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "destroy",
            receiver_first_name: "Gigi",
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "WATER BILL",
              date: "2026-03-17",
              reference_month_year: "MAR <26>",
              price: -5000,
              installments_count: 1,
              installments: [
                { number: 1, date: "2026-03-20", price: -5000 }
              ]
            }
          },
          replay: nil
        }.to_json
      )

      expect(message.transaction_destroy_notification_message?).to be(true)
      expect(message.backfill_kind).to eq("transaction_destroy_notification")
    end

    it "renders v2 destroy notification bodies from headers at display time" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "destroy",
            receiver_first_name: "Gigi",
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "WATER BILL",
              date: "2026-03-17",
              reference_month_year: "MAR <26>",
              price: -5000,
              installments_count: 1,
              installments: [
                { number: 1, date: "2026-03-20", price: -5000 }
              ]
            }
          },
          replay: nil
        }.to_json
      )

      expect(message.rendered_body).to include("WATER BILL")
      expect(message.rendered_body).not_to eq("notification:destroy")
      expect(message.preview_body).to include("WATER BILL")
    end

    it "renders paid-state synchronization messages from headers at display time" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:paid_state",
        headers: {
          version: "message_paid_state_v1",
          event: {
            action: "paid",
            receiver_first_name: "Gigi",
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "SHARED RETURN",
              installment_number: 1,
              installments_count: 1,
              date: "2026-03-20",
              paid: true
            }
          }
        }.to_json
      )

      expect(message.paid_state_sync_message?).to be(true)
      expect(message.transaction_notification_message?).to be(false)
      expect(message.rendered_body).to include("SHARED RETURN")
      expect(message.preview_body).to include("SHARED RETURN")
      expect(message.preview_body).to include(I18n.t("activerecord.attributes.message.notification_actions.paid"))
    end

    it "classifies headerless messages without reference transactable as human chat" do
      message = described_class.create!(
        conversation:,
        user: sender,
        body: "hello"
      )

      expect(message.human_message?).to be(true)
      expect(message.backfill_kind).to eq("human")
    end

    it "derives create, correct, and edit button states from applied_at and notification type" do
      create_message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: "Gigi", transaction_type: "CashTransaction", details: {} },
          replay: { id: reference_transaction.id, type: "CashTransaction" }
        }.to_json
      )
      update_message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: "Gigi", transaction_type: "CashTransaction", details: {} },
          replay: { id: reference_transaction.id, type: "CashTransaction" }
        }.to_json
      )

      expect(create_message.action_button_key(local_reference_exists: false)).to eq(:create)
      expect(update_message.action_button_key(local_reference_exists: true)).to eq(:correct)
      expect(create_message.completed_message_key).to eq(:already_created)
      expect(update_message.completed_message_key).to eq(:already_updated)

      update_message.update!(applied_at: Time.current)

      expect(update_message.action_button_key(local_reference_exists: true)).to eq(:edit)
    end

    it "resolves a local reference through an applied predecessor in the same message chain" do
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      local_reference = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        description: "Original borrow return",
        price: -20_000,
        date: Time.zone.parse("2026-03-24")
      )

      predecessor = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        applied_at: Time.current,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: "Gigi", transaction_type: "CashTransaction", details: {} },
          replay: {
            id: reference_transaction.id,
            type: "CashTransaction",
            intent: "reimbursement",
            description: "Original borrow return",
            price: -20_000,
            date: "2026-03-24T00:00:00-03:00"
          }
        }.to_json
      )

      latest_update = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: "Gigi", transaction_type: "CashTransaction", details: {} },
          replay: {
            id: reference_transaction.id,
            type: "CashTransaction",
            intent: "reimbursement",
            description: "Updated borrow return",
            price: -25_000,
            date: "2026-03-25T00:00:00-03:00"
          }
        }.to_json
      )
      predecessor.update!(superseded_by: latest_update)

      expect(latest_update.local_reference_for(context: receiver.main_context)).to eq(local_reference)
      expect(latest_update.actionable_for?(context: receiver.main_context)).to be(true)
      expect(latest_update.action_button_key(local_reference_exists: latest_update.local_reference_for(context: receiver.main_context).present?)).to eq(:correct)
    end

    it "resolves a card-origin shared return update to the local exchange return projection" do
      sender_entity_for_receiver =
        sender.entities.find_or_create_by!(entity_name: receiver.first_name.upcase) do |entity_record|
          entity_record.entity_user = receiver
        end
      receiver.entities.find_or_create_by!(entity_name: sender.first_name.upcase) do |entity_record|
        entity_record.entity_user = sender
      end

      sender_user_card = create(:user_card, :random, user: sender, card: create(:card, :random, bank: create(:bank, :random)))
      origin_card_transaction = create(
        :card_transaction,
        user: sender,
        context: sender.main_context,
        user_card: sender_user_card,
        description: "Card-origin shared return",
        date: Date.new(2026, 3, 15),
        month: 4,
        year: 2026,
        price: -2_000
      )
      origin_card_transaction.category_transactions.destroy_all
      origin_card_transaction.category_transactions.create!(category: sender.built_in_category("EXCHANGE"))
      payer_entity_transaction = origin_card_transaction.entity_transactions.first
      payer_entity_transaction.update!(
        entity_id: sender_entity_for_receiver.id,
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

      local_exchange_return = first_exchange.cash_transaction.reload
      update_message = described_class.create!(
        conversation:,
        user: receiver,
        reference_transactable: origin_card_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: sender.first_name, transaction_type: "CardTransaction", details: {} },
          replay: {
            id: origin_card_transaction.id,
            type: "CardTransaction",
            description: local_exchange_return.description,
            price: -2_000,
            date: "2026-03-20T00:00:00-03:00",
            month: 3,
            year: 2026,
            cash_installments_attributes: [
              { number: 1, price: -1_000, paid: true, date: "2026-03-20T00:00:00-03:00", month: 3, year: 2026 },
              { number: 2, price: -1_000, paid: false, date: "2026-04-20T00:00:00-03:00", month: 4, year: 2026 }
            ]
          }
        }.to_json
      )

      expect(update_message.local_reference_for(context: sender.main_context)).to eq(local_exchange_return)
      expect(update_message.action_button_key(local_reference_exists: update_message.local_reference_for(context: sender.main_context).present?)).to eq(:correct)
    end

    it "resolves a cash-origin shared return update directly by local cash transaction id" do
      local_exchange_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random)),
        description: "Sender shared return",
        price: 12_000,
        date: Time.zone.parse("2026-03-30 16:58:00 -03:00")
      )

      update_message = described_class.create!(
        conversation:,
        user: receiver,
        reference_transactable: local_exchange_return,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: sender.first_name, transaction_type: "CashTransaction", details: {} },
          replay: {
            id: local_exchange_return.id,
            type: "CashTransaction",
            description: local_exchange_return.description,
            price: local_exchange_return.price,
            date: local_exchange_return.date.iso8601
          }
        }.to_json
      )

      expect(update_message.local_reference_for(context: sender.main_context)).to eq(local_exchange_return)
      expect(update_message.action_button_key(local_reference_exists: update_message.local_reference_for(context: sender.main_context).present?)).to eq(:correct)
    end
  end
end

# == Schema Information
#
# Table name: messages
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  applied_at                  :datetime         indexed
#  body                        :text
#  headers                     :text
#  read_at                     :datetime
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  conversation_id             :bigint           not null, indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  superseded_by_id            :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_messages_on_applied_at              (applied_at)
#  index_messages_on_conversation_id         (conversation_id)
#  index_messages_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_messages_on_superseded_by_id        (superseded_by_id)
#  index_messages_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (superseded_by_id => messages.id)
#  fk_rails_...  (user_id => users.id)
#
