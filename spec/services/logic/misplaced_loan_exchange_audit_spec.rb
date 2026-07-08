# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::MisplacedLoanExchangeAudit do
  describe "#call" do
    it "only reports misplaced loan source transactions owned by the current user" do
      user = create(:user, :random)
      connected_user = create(:user, :random)
      user_source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        price: -10_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: create(:entity, user:, entity_user: connected_user).id, price: -5_000, price_to_be_returned: -5_000 } ]
      )
      connected_source = create(
        :cash_transaction,
        user: connected_user,
        context: connected_user.main_context,
        user_bank_account: create(:user_bank_account, user: connected_user, bank: create(:bank, :random)),
        price: -10_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: connected_user.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: create(:entity, user: connected_user, entity_user: user).id, price: -5_000, price_to_be_returned: -5_000 } ]
      )
      audit = described_class.new(current_user: user)
      allow(audit).to receive(:exchange_rows).and_return([
                                                           {
                                                             source: { id: user_source.id, type: "CashTransaction", user_id: user.id },
                                                             message: { id: 1 },
                                                             intent: "loan"
                                                           },
                                                           {
                                                             source: { id: connected_source.id, type: "CashTransaction", user_id: connected_user.id },
                                                             message: { id: 2 },
                                                             intent: "loan"
                                                           }
                                                         ])

      expect(audit.call.map { |row| row[:source_id] }).to eq([ user_source.id ])
    end
  end

  describe "#convert!" do
    it "converts the source transaction and active message replay intents to reimbursement" do
      user = create(:user, :random)
      receiver = create(:user, :random)
      source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE").id } ]
      )
      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      message_insert = Message.insert!({
                                         user_id: user.id,
                                         conversation_id: conversation.id,
                                         reference_transactable_type: "CashTransaction",
                                         reference_transactable_id: source.id,
                                         body: "notification:update",
                                         headers: {
                                           version: "message_notification_v2",
                                           event: { action: "update", details: { description: source.description } },
                                           replay: {
                                             id: source.id,
                                             type: "CashTransaction",
                                             intent: "loan"
                                           }
                                         }.to_json,
                                         created_at: Time.current,
                                         updated_at: Time.current
                                       })
      message = Message.find(message_insert.rows.first.first)
      audit = described_class.new(current_user: user)
      allow(audit).to receive(:call).and_return([
                                                  {
                                                    source_id: source.id,
                                                    message_ids: [ message.id ]
                                                  }
                                                ])
      allow(audit).to receive(:source_transactions).and_return({ source.id => source })

      result = audit.convert!(source_id: source.id)

      expect(result).to eq(source_id: source.id, updated_message_count: 1)
      expect(source.reload.friend_notification_intent).to eq("reimbursement")
      expect(message.reload.replay_payload["intent"]).to eq("reimbursement")
    end
  end

  describe "#convert_exchange_audit_issue!" do
    it "converts loan rows flagged with missing receiver exchange return even when totals match" do
      user = create(:user, :random)
      source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE").id } ]
      )
      receiver = create(:user, :random)
      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      message_insert = Message.insert!({
                                         user_id: user.id,
                                         conversation_id: conversation.id,
                                         reference_transactable_type: "CashTransaction",
                                         reference_transactable_id: source.id,
                                         body: "notification:update",
                                         headers: {
                                           version: "message_notification_v2",
                                           replay: {
                                             id: source.id,
                                             type: "CashTransaction",
                                             intent: "loan"
                                           }
                                         }.to_json,
                                         created_at: Time.current,
                                         updated_at: Time.current
                                       })
      message = Message.find(message_insert.rows.first.first)
      audit = described_class.new(current_user: user)
      allow(audit).to receive(:exchange_rows).and_return([])

      result = audit.convert_exchange_audit_issue!(source_id: source.id)

      expect(result).to eq(status: "converted", source_id: source.id, updated_message_count: 1)
      expect(source.reload.friend_notification_intent).to eq("reimbursement")
      expect(message.reload.replay_payload["intent"]).to eq("reimbursement")
    end

    it "does not convert a connected user's source transaction" do
      user = create(:user, :random)
      owner = create(:user, :random)
      source = create(
        :cash_transaction,
        user: owner,
        context: owner.main_context,
        user_bank_account: create(:user_bank_account, user: owner, bank: create(:bank, :random)),
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: owner.built_in_category("EXCHANGE").id } ]
      )
      audit = described_class.new(current_user: user)

      result = audit.convert_exchange_audit_issue!(source_id: source.id)

      expect(result).to eq(status: "unavailable", source_id: source.id, reason: "owner_only", updated_message_count: 0)
      expect(source.reload.friend_notification_intent).to eq("loan")
    end
  end
end
