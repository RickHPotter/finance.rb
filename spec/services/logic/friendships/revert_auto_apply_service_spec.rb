# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Friendships::RevertAutoApplyService do
  let(:sender) { create(:user, email: "sender@example.com") }
  let(:recipient) { create(:user, email: "recipient@example.com") }
  let!(:friendship) { create(:friendship, user: recipient, friend: sender, state: "accepted") }
  let(:conversation) { Conversation.find_or_create_assistant_between!(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key) }
  let(:message) do
    conversation.messages.create!(
      user: sender,
      body: "test",
      auto_applied: true,
      headers: {
        version: "message_notification_v2",
        event: { action: "create", transaction_type: "CashTransaction", receiver_first_name: recipient.first_name, details: { description: "Dinner" } }
      }.to_json
    )
  end

  subject(:service) { described_class.new(message: message, actor: actor, context: recipient.ensure_main_context!) }
  let(:actor) { recipient }

  context "when unauthorized" do
    let(:actor) { sender }

    it "fails with unauthorized" do
      result = service.call
      expect(result.reverted?).to be false
      expect(result.failure_reason).to eq("unauthorized")
    end
  end

  context "when already reverted" do
    before { message.update!(reverted_at: Time.current) }

    it "fails with already_reverted" do
      result = service.call
      expect(result.reverted?).to be false
      expect(result.failure_reason).to eq("already_reverted")
    end
  end

  context "when not auto-applied" do
    before { message.update!(auto_applied: false) }

    it "fails with not_auto_applied" do
      result = service.call
      expect(result.reverted?).to be false
      expect(result.failure_reason).to eq("not_auto_applied")
    end
  end

  context "when valid" do
    let(:original_op) do
      AuditOperation.create!(
        source: "actionable_message",
        actor_id: sender.id,
        context_id: sender.ensure_main_context!.id,
        request_id: SecureRandom.uuid,
        result: "committed"
      )
    end

    before do
      message.update!(audit_operation_id: original_op.id)

      allow(Audit::Rollback::DirectApply).to receive(:new).and_return(
        Class.new do
          def call
            rollback_op = Audit::Operation.ensure_persisted!
            Audit::Rollback::ApplyResult.new(status: "applied", operation: rollback_op, reason_code: nil, duplicate: false)
          end
        end.new
      )
    end

    it "reverts the message and sets reverted_at" do
      expect { service.call }.to change { message.reload.reverted_at }.from(nil)
    end

    it "returns success" do
      result = service.call
      expect(result.reverted?).to be true
    end

    it "creates a rollback AuditOperation linked to the original" do
      expect { service.call }.to change { AuditOperation.where(source: "rollback").count }.by(1)

      rollback_op = AuditOperation.where(source: "rollback").last
      expect(rollback_op.rollback_of_operation_id).to eq(original_op.id)
      expect(rollback_op.parent_operation_id).to eq(message.audit_operation_id)
      expect(rollback_op.actor_id).to eq(recipient.id)
    end
  end
end
