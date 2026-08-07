# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Friendships::AutoAcceptActionableMessageService do
  # Two users with an accepted friendship. The sender (rikki) sends an
  # actionable message; the recipient (gigi) has auto_accept enabled.
  let(:sender)    { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let(:friendship) do
    create(:friendship, :accepted, user: sender, friend: recipient).tap do |f|
      f.update!(auto_accept_actionable_messages: true)
    end
  end

  let(:sender_bank)     { create(:user_bank_account, user: sender, bank: create(:bank, :random)) }
  let(:recipient_bank)  { create(:user_bank_account, user: recipient, bank: create(:bank, :random)) }

  # Shared return entity pair
  let!(:sender_entity) do
    sender.entities.create!(entity_name: "GIGI", friendship_id: friendship.id, built_in: false)
  end
  let!(:recipient_entity) do
    recipient.entities.create!(entity_name: "RIKKI", friendship_id: friendship.id, built_in: false)
  end

  # A simple helper that creates a message in the assistant conversation between
  # sender and recipient, with the supplied replay payload.
  def build_message(action:, payload:)
    conversation = Conversation.find_or_create_assistant_between!(
      sender,
      recipient,
      scenario_key: sender.ensure_main_context!.scenario_key
    )
    conversation.messages.create!(
      user: sender,
      body: "notification:#{action}",
      headers: {
        version: "message_notification_v2",
        event: {
          action:,
          receiver_first_name: recipient.first_name,
          transaction_type: "CashTransaction",
          details: { description: "Dinner" }
        },
        replay: payload
      }.to_json
    )
  end

  around { |ex| perform_enqueued_jobs { ex.run } }

  # ─── Policy guard ────────────────────────────────────────────────────────────

  describe "#call — policy guard" do
    context "when auto_accept_actionable_messages is false" do
      before { friendship.update!(auto_accept_actionable_messages: false) }

      it "does not apply the message" do
        payload = { id: nil, type: "CashTransaction", description: "Dinner", price: 100,
                    date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year,
                    category_ids: recipient.built_in_category("EXCHANGE").id,
                    cash_installments_attributes: [
                      { number: 1, date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year, price: 100 }
                    ] }
        msg = build_message(action: "create", payload:)

        expect { described_class.new(msg).call }.not_to change(CashTransaction, :count)
        expect(msg.reload.applied_at).to be_nil
      end
    end

    context "when there is no friendship" do
      before { friendship.destroy! }

      it "does not apply the message" do
        # Create a bare conversation without the friendship guard
        conversation = Conversation.find_or_create_assistant_between!(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
        msg = conversation.messages.create!(
          user: sender, body: "notification:create",
          headers: {
            version: "message_notification_v2",
            event: { action: "create", transaction_type: "CashTransaction", receiver_first_name: recipient.first_name, details: { description: "Dinner" } },
            replay: {}
          }.to_json
        )
        expect { described_class.new(msg).call }.not_to change(CashTransaction, :count)
        expect(msg.reload.applied_at).to be_nil
      end
    end
  end

  # ─── Safety guards ───────────────────────────────────────────────────────────

  describe "#call — safety guards" do
    it "does not apply destroy-type messages" do
      conversation = Conversation.find_or_create_assistant_between!(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
      msg = conversation.messages.create!(
        user: sender, body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: { action: "destroy", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: nil
        }.to_json
      )
      expect { described_class.new(msg).call }.not_to change(CashTransaction, :count)
      expect(msg.reload.applied_at).to be_nil
    end

    it "applies messages with paid installments" do
      payload = {
        id: nil, type: "CashTransaction", description: "Paid trip", price: 200,
        date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year,
        cash_installments_attributes: [
          { number: 1, date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year, price: 200, paid: true }
        ]
      }
      msg = build_message(action: "create", payload:)
      expect { described_class.new(msg).call }.to change(CashTransaction, :count).by(1)
      expect(msg.reload.applied_at).not_to be_nil
    end

    it "does not apply paid_state_sync messages" do
      conversation = Conversation.find_or_create_assistant_between!(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
      msg = conversation.messages.create!(
        user: sender, body: "notification:paid_state_sync",
        headers: {
          version: "message_notification_v2",
          event: { action: "paid_state_sync", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: nil
        }.to_json
      )
      expect { described_class.new(msg).call }.not_to change(CashTransaction, :count)
      expect(msg.reload.applied_at).to be_nil
    end
  end

  # ─── Create action ────────────────────────────────────────────────────────────

  describe "#call — create action" do
    let(:category) { recipient.built_in_category("EXCHANGE") }
    let(:payload) do
      {
        id: nil,
        type: "CashTransaction",
        intent: "loan",
        description: "Dinner",
        price: 100,
        date: Time.zone.today.iso8601,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        category_ids: category.id,
        cash_installments_attributes: [
          { number: 1, date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year, price: 100 }
        ]
      }
    end

    let!(:msg) { build_message(action: "create", payload:) }

    it "creates a cash transaction on the recipient's context" do
      expect { described_class.new(msg).call }
        .to change { recipient.ensure_main_context!.cash_transactions.count }.by(1)
    end

    it "does not create a cash transaction on the sender's context" do
      expect { described_class.new(msg).call }
        .not_to(change { sender.ensure_main_context!.cash_transactions.count })
    end

    it "sets applied_at on the message" do
      described_class.new(msg).call
      expect(msg.reload.applied_at).not_to be_nil
    end

    it "creates an AuditOperation linked to the message's audit_operation_id" do
      expect { described_class.new(msg).call }
        .to change { AuditOperation.where(source: "actionable_message").count }.by_at_least(1)
    end
  end

  # ─── Update action ────────────────────────────────────────────────────────────

  describe "#call — update action" do
    let(:category) { recipient.built_in_category("EXCHANGE") }
    let!(:existing_ct) do
      recipient.ensure_main_context!.cash_transactions.create!(
        user: recipient,
        description: "Old dinner",
        date: 1.week.ago,
        month: 1.week.ago.month,
        year: 1.week.ago.year,
        price: 50,
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: category.id } ]
      ).tap do |ct|
        ct.cash_installments.create!(number: 1, date: ct.date, month: ct.month, year: ct.year, price: 50)
      end
    end

    # A "sender-side" transaction that acts as the reference_transactable for the message
    let!(:sender_ct) do
      sender.ensure_main_context!.cash_transactions.create!(
        user: sender,
        description: "Dinner",
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        price: 100,
        reference_transactable: nil,
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ]
      ).tap do |ct|
        ct.cash_installments.create!(number: 1, date: ct.date, month: ct.month, year: ct.year, price: 100)
      end
    end

    before do
      # The update message points to the existing_ct via reference_transactable
      existing_ct.update!(reference_transactable: sender_ct)
    end

    let(:payload) do
      {
        id: sender_ct.id,
        type: "CashTransaction",
        intent: "loan",
        description: "Updated dinner",
        price: 120,
        date: Time.zone.today.iso8601,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        cash_installments_attributes: [
          { number: 1, date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year, price: 120 }
        ]
      }
    end

    let!(:msg) do
      conversation = Conversation.find_or_create_assistant_between!(
        sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key
      )
      conversation.messages.create!(
        user: sender,
        reference_transactable: sender_ct,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: payload
        }.to_json
      )
    end

    it "updates the existing cash transaction on the recipient's context" do
      described_class.new(msg).call
      expect(existing_ct.reload.description).to eq("Updated dinner")
      expect(existing_ct.reload.price).to eq(120)
    end

    it "does not create a new cash transaction" do
      expect { described_class.new(msg).call }
        .not_to(change { recipient.ensure_main_context!.cash_transactions.count })
    end

    it "sets applied_at on the message" do
      described_class.new(msg).call
      expect(msg.reload.applied_at).not_to be_nil
    end
  end

  # ─── Policy — typed boolean attribute ─────────────────────────────────────────

  describe "Friendship#auto_accept_actionable_messages type cast" do
    it "returns a proper boolean true when set to true" do
      expect(friendship.auto_accept_actionable_messages).to be(true)
    end

    it "returns a proper boolean false when set to false" do
      friendship.update!(auto_accept_actionable_messages: false)
      expect(friendship.reload.auto_accept_actionable_messages).to be(false)
    end

    it "returns false when the JSONB value is nil" do
      friendship.update_column(:policies, {})
      expect(friendship.reload.auto_accept_actionable_messages).to be_falsy
    end
  end
end
