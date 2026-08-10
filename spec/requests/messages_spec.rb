# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:conversation) do
    Conversation.create!.tap do |c|
      c.conversation_participants.create!(user:)
      c.conversation_participants.create!(user: other_user)
    end
  end

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a message for the conversation" do
      expect do
        post conversation_messages_path(conversation), params: {
          message: { body: "Hello there" }
        }, headers: turbo_stream_headers
      end.to change(Message, :count).by(1)

      message = Message.last

      expect(message.conversation).to eq(conversation)
      expect(message.user).to eq(user)
      expect(message.body).to eq("Hello there")
    end

    it "creates a message inside a derived-scenario conversation" do
      derived_context = create(:context, user:, name: "Message Scenario", source_context: user.main_context)
      derived_conversation = Conversation.find_or_create_human_between!(user, other_user, scenario_key: derived_context.scenario_key)

      patch switch_context_path(derived_context)

      expect do
        post conversation_messages_path(derived_conversation), params: {
          message: { body: "Derived hello" }
        }, headers: turbo_stream_headers
      end.to change(Message, :count).by(1)

      expect(Message.last.conversation).to eq(derived_conversation)
    end

    it "does not allow posting to a conversation from another scenario" do
      derived_context = create(:context, user:, name: "Message Access", source_context: user.main_context)

      patch switch_context_path(derived_context)

      post conversation_messages_path(conversation), params: {
        message: { body: "Wrong place" }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "[ #revert ]" do
    let(:friendship) { create(:friendship, user: user, friend: other_user, state: "accepted") }
    let(:message) do
      conversation.messages.create!(
        user: other_user,
        body: "friend message",
        auto_applied: true,
        headers: {
          version: "message_notification_v2",
          event: { action: "create", transaction_type: "CashTransaction", receiver_first_name: user.first_name, details: { description: "Dinner" } }
        }.to_json
      )
    end

    before { friendship }

    it "reverts an auto-applied message" do
      allow_any_instance_of(Logic::Friendships::RevertAutoApplyService).to receive(:call).and_return(
        Audit::Rollback::ApplyResult.new(status: "applied", operation: nil, reason_code: nil, duplicate: false)
      )

      patch revert_conversation_message_path(conversation, message), headers: turbo_stream_headers
      expect(response).to have_http_status(:ok)
    end

    it "rolls back the transaction created by auto-apply" do
      friendship.update!(auto_accept_actionable_messages: true)
      sender_account = create(:user_bank_account, :random, user: other_user)
      sender_source = create(
        :cash_transaction,
        user: other_user,
        context: other_user.main_context,
        user_bank_account: sender_account,
        description: "Sender dinner source"
      )
      actionable_message = nil

      Audit::Operation.run(source: :web, actor: other_user, context: other_user.main_context, join_existing: false) do
        Audit::Operation.ensure_persisted!
        actionable_message = conversation.messages.create!(
          user: other_user,
          body: "notification:create",
          headers: {
            version: "message_notification_v2",
            event: {
              action: "create",
              transaction_type: "CashTransaction",
              receiver_first_name: user.first_name,
              details: { description: "Revert auto-applied dinner" }
            },
            replay: {
              id: sender_source.id,
              type: "CashTransaction",
              description: "Revert auto-applied dinner",
              price: 1_000,
              date: Time.zone.today.iso8601,
              month: Time.zone.today.month,
              year: Time.zone.today.year,
              cash_installments_attributes: [
                {
                  number: 1,
                  date: Time.zone.today.iso8601,
                  month: Time.zone.today.month,
                  year: Time.zone.today.year,
                  price: 1_000,
                  paid: false
                }
              ]
            }
          }.to_json
        )
      end

      created_transaction = user.main_context.cash_transactions.find_by!(description: "Revert auto-applied dinner")
      expect(actionable_message.reload).to be_auto_applied
      expect(actionable_message.audit_operation).to be_source_actionable_message
      preview = Audit::Rollback::Preview.new(operation: actionable_message.audit_operation, actor: user)
      expect(preview.state).to eq("previewable"), preview.digest_payload.inspect

      patch revert_conversation_message_path(conversation, actionable_message), headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(CashTransaction.exists?(created_transaction.id)).to be(false)
      expect(actionable_message.reload).to be_reverted
    end

    it "rolls back a safely audited manual application" do
      account = create(:user_bank_account, :random, user:)
      transaction = PaperTrail.request(enabled: false) do
        create(
          :cash_transaction,
          user:,
          context: user.main_context,
          user_bank_account: account,
          description: "Before manual apply"
        )
      end
      operation = nil
      Audit::Operation.run(source: :web, actor: user, context: user.main_context) do
        transaction.update!(description: "After manual apply")
        operation = Audit::Operation.ensure_persisted!
      end
      manually_applied_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        applied_at: Time.current,
        audit_operation: operation,
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            transaction_type: "CashTransaction",
            receiver_first_name: user.first_name,
            details: { description: "After manual apply" }
          },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      patch revert_conversation_message_path(conversation, manually_applied_message), headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(transaction.reload.description).to eq("Before manual apply")
      expect(manually_applied_message.reload).to be_reverted
    end
  end
end
