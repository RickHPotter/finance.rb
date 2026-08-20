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
  def build_message(action:, payload:, reference_transactable: nil)
    conversation = resolve_assistant_conversation(
      sender,
      recipient,
      scenario_key: sender.ensure_main_context!.scenario_key
    )
    conversation.messages.create!(
      user: sender,
      reference_transactable:,
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

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

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
        # Preserve a deliberately legacy bare conversation to characterize the
        # application service's defense when canonical friendship identity is absent.
        conversation = Conversation.create!(kind: :assistant, scenario_key: sender.ensure_main_context!.scenario_key).tap do |record|
          record.conversation_participants.create!(user: sender)
          record.conversation_participants.create!(user: recipient)
        end
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
    it "auto-applies an unambiguous destroy for an unpaid linked exchange" do
      sender_source = create(:cash_transaction, user: sender, context: sender.main_context, user_bank_account: sender_bank)
      recipient_exchange = create(
        :cash_transaction,
        user: recipient,
        context: recipient.main_context,
        user_bank_account: recipient_bank,
        reference_transactable: sender_source
      )
      recipient_exchange.categories = [ recipient.built_in_category("EXCHANGE") ]
      recipient_exchange.friend_notification_intent = "loan"
      recipient_exchange.entity_transactions.create!(entity: recipient_entity, price: 100, price_to_be_returned: 100, is_payer: true)
      recipient_exchange.save!

      conversation = resolve_assistant_conversation(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
      msg = conversation.messages.create!(
        user: sender,
        reference_transactable: recipient_exchange,
        body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: { action: "destroy", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: nil
        }.to_json
      )

      described_class.new(msg).call

      expect(CashTransaction.exists?(recipient_exchange.id)).to be(false)
      expect(msg.reload).to be_auto_applied
    end

    it "auto-applies an unambiguous destroy for an unpaid borrow return whose source was destroyed" do
      recipient_return = create(
        :cash_transaction,
        user: recipient,
        context: recipient.main_context,
        user_bank_account: recipient_bank
      )
      recipient_return.categories = [ recipient.built_in_category("BORROW RETURN") ]
      recipient_return.entity_transactions.create!(entity: recipient_entity, price: 0, price_to_be_returned: 0, is_payer: false)
      recipient_return.save!

      conversation = resolve_assistant_conversation(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
      msg = conversation.messages.create!(
        user: sender,
        reference_transactable: recipient_return,
        body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: { action: "destroy", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: nil
        }.to_json
      )

      described_class.new(msg).call

      expect(CashTransaction.exists?(recipient_return.id)).to be(false)
      expect(msg.reload).to be_auto_applied
    end

    it "does not auto-apply destroy messages for paid linked exchanges" do
      sender_source = create(:cash_transaction, user: sender, context: sender.main_context, user_bank_account: sender_bank)
      recipient_exchange = create(
        :cash_transaction,
        user: recipient,
        context: recipient.main_context,
        user_bank_account: recipient_bank,
        reference_transactable: sender_source
      )
      recipient_exchange.categories = [ recipient.built_in_category("EXCHANGE") ]
      recipient_exchange.friend_notification_intent = "loan"
      recipient_exchange.entity_transactions.create!(entity: recipient_entity, price: 100, price_to_be_returned: 100, is_payer: true)
      recipient_exchange.save!
      recipient_exchange.cash_installments.first.update!(paid: true)

      conversation = resolve_assistant_conversation(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
      msg = conversation.messages.create!(
        user: sender,
        reference_transactable: recipient_exchange,
        body: "notification:destroy",
        headers: {
          version: "message_notification_v2",
          event: { action: "destroy", receiver_first_name: recipient.first_name, transaction_type: "CashTransaction", details: {} },
          replay: nil
        }.to_json
      )

      described_class.new(msg).call

      expect(CashTransaction.exists?(recipient_exchange.id)).to be(true)
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
      conversation = resolve_assistant_conversation(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key)
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

    it "applies duplicate job delivery only once" do
      service = described_class.new(msg)

      expect do
        service.call
        service.call
      end.to change { recipient.ensure_main_context!.cash_transactions.count }.by(1)

      expect(msg.reload.message_actions.order(:id).pluck(:outcome)).to eq(%w[succeeded idempotent])
    end

    it "sets applied_at on the message" do
      described_class.new(msg).call
      expect(msg.reload.applied_at).not_to be_nil
    end

    it "links the successful action event to its exact actionable audit operation without replacing message provenance" do
      described_class.new(msg).call

      action = msg.reload.message_actions.find_by!(action: :apply, outcome: :succeeded)
      operation = action.audit_operation
      expect(operation).to have_attributes(source: "actionable_message", actor_id: recipient.id, context_id: recipient.main_context.id)
      expect(operation.metadata).to include("actionable_message_id" => msg.id)
      expect(msg.audit_operation_id).to be_nil
    end

    it "creates an AuditOperation linked to the message's audit_operation_id" do
      expect { described_class.new(msg).call }
        .to change { AuditOperation.where(source: "actionable_message").count }.by_at_least(1)
    end

    it "creates a loan exchange from the full actionable replay payload" do
      loan_payload = payload.merge(
        entity_transactions_attributes: [
          {
            entity_id: recipient_entity.id,
            is_payer: true,
            price: 100,
            price_to_be_returned: 100,
            exchanges_count: 1,
            exchanges_attributes: [
              {
                number: 1,
                exchange_type: "monetary",
                date: Time.zone.today.iso8601,
                month: Time.zone.today.month,
                year: Time.zone.today.year,
                price: 100,
                paid: false
              }
            ]
          }
        ]
      )
      loan_message = build_message(action: "create", payload: loan_payload)
      recipient_exchanges = recipient.ensure_main_context!.cash_transactions.joins(:categories).where(categories: { category_name: "EXCHANGE" })
      existing_exchange_ids = recipient_exchanges.ids

      expect { described_class.new(loan_message).call }
        .to change(recipient_exchanges, :count).by(1)

      created_transaction = recipient_exchanges.where.not(id: existing_exchange_ids).find_by!(description: "Dinner")
      expect(created_transaction).to have_attributes(friend_notification_intent: "loan")
      expect(created_transaction.entity_transactions.first.exchanges.first).to have_attributes(exchange_type: "monetary", price: 100)
      expect(loan_message.reload).to be_auto_applied
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
      conversation = resolve_assistant_conversation(
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

    it "auto-applies a loan-to-reimbursement conversion and removes the receiver exchange structure" do
      sender_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank,
        reference_transactable: sender_ct,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ]
      )
      sender_entity_transaction = sender_ct.entity_transactions.create!(
        entity: sender_entity,
        is_payer: true,
        price: 50,
        price_to_be_returned: 50,
        exchanges_count: 1
      )
      create(
        :exchange,
        entity_transaction: sender_entity_transaction,
        cash_transaction: sender_return,
        exchange_type: :monetary,
        number: 1,
        price: 50,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )
      entity_transaction = existing_ct.entity_transactions.create!(
        entity: recipient_entity,
        is_payer: true,
        price: -50,
        price_to_be_returned: -50,
        exchanges_count: 1
      )
      exchange = create(
        :exchange,
        entity_transaction:,
        exchange_type: :monetary,
        number: 1,
        price: -50,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )
      reimbursement_message = build_message(
        action: "update",
        reference_transactable: sender_ct,
        payload: {
          id: sender_ct.id,
          type: "CashTransaction",
          version: "cash_exchange_v2",
          intent: "reimbursement",
          description: "Updated reimbursement",
          price: -50,
          date: Time.zone.today.iso8601,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          category_ids: recipient.built_in_category("BORROW RETURN").id,
          cash_installments_attributes: [
            { number: 1, date: Time.zone.today.iso8601, month: Time.zone.today.month, year: Time.zone.today.year, price: -50 }
          ],
          entity_transactions_attributes: [
            {
              entity_id: recipient_entity.id,
              is_payer: false,
              price: 0,
              price_to_be_returned: 0,
              exchanges_count: 0,
              exchanges_attributes: []
            }
          ]
        }
      )

      described_class.new(reimbursement_message).call

      expect(existing_ct.reload.categories.pluck(:category_name)).to eq([ "BORROW RETURN" ])
      expect(existing_ct.friend_notification_intent).to be_nil
      expect(existing_ct.reference_transactable).to eq(sender_return)
      expect(Exchange.exists?(exchange.id)).to be(false)
      expect(reimbursement_message.reload).to be_auto_applied
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
