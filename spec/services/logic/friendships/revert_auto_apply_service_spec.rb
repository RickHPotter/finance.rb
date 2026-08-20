# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Friendships::RevertAutoApplyService do
  let(:sender) { create(:user, email: "sender@example.com") }
  let(:recipient) { create(:user, email: "recipient@example.com") }
  let!(:friendship) { create(:friendship, user: recipient, friend: sender, state: "accepted") }
  let(:conversation) { resolve_assistant_conversation(sender, recipient, scenario_key: sender.ensure_main_context!.scenario_key) }
  let(:message) do
    conversation.messages.create!(
      user: sender,
      body: "test",
      applied_at: Time.current,
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

  context "when not applied" do
    before { message.update!(applied_at: nil, auto_applied: false) }

    it "fails with not_applied" do
      result = service.call
      expect(result.reverted?).to be false
      expect(result.failure_reason).to eq("not_applied")
    end
  end

  context "when superseded" do
    before do
      newer_message = conversation.messages.create!(user: sender, body: "newer message")
      message.update!(superseded_by: newer_message)
    end

    it "does not offer or perform a revert" do
      expect(service.revertible?).to be(false)
      expect(service.call.failure_reason).to eq("superseded")
      expect(message.message_actions.last).to have_attributes(
        action: "revert",
        outcome: "denied",
        error_code: "superseded",
        resulting_state: "accepted"
      )
    end
  end

  context "when friendship access has been revoked" do
    before do
      message
      friendship.update!(state: "blocked")
    end

    it "keeps the applied state intact and denies revert" do
      expect(service.revertible?).to be(false)
      expect(service.call.failure_reason).to eq("unauthorized")
      expect(message.reload.workflow_state).to eq("accepted")
      expect(message.message_actions.last).to have_attributes(
        action: "revert",
        outcome: "denied",
        error_code: "friendship_unavailable"
      )
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
      allow(Audit::Rollback::Preview).to receive(:new).and_return(instance_double(Audit::Rollback::Preview, state: "previewable"))

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

      event = message.message_actions.find_by!(action: :revert, outcome: :succeeded)
      expect(event.audit_operation).to be_source_rollback
      expect(event.resulting_state).to eq("reverted")
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

    it "denies revert when later mutations make the operation unsafe" do
      allow(Audit::Rollback::Preview).to receive(:new).and_return(instance_double(Audit::Rollback::Preview, state: "conflicted"))

      result = service.call

      expect(result).to have_attributes(reverted?: false, failure_reason: "rollback_unavailable")
      expect(message.reload.workflow_state).to eq("accepted")
      expect(message.message_actions.last).to have_attributes(
        action: "revert",
        outcome: "denied",
        error_code: "unavailable"
      )
    end
  end

  context "with a legacy message linked to the parent web operation" do
    it "resolves the recipient's sole actionable child operation" do
      parent_operation = AuditOperation.create!(
        source: "web",
        actor_id: sender.id,
        context_id: sender.main_context.id,
        result: "committed"
      )
      actionable_operation = AuditOperation.create!(
        source: "actionable_message",
        actor_id: recipient.id,
        context_id: recipient.main_context.id,
        parent_operation_id: parent_operation.id,
        result: "committed"
      )
      message.update!(audit_operation_id: parent_operation.id)

      expect(service.send(:auto_apply_operation)).to eq(actionable_operation)
    end
  end

  context "with a manually applied message linked to the recipient's operation" do
    it "is revertible when the operation still has a safe preview" do
      operation = AuditOperation.create!(
        source: "web",
        actor_id: recipient.id,
        context_id: recipient.main_context.id,
        result: "committed"
      )
      AuditVersion.create!(
        operation:,
        owner_id: recipient.id,
        context_id: recipient.main_context.id,
        item_type: "CashTransaction",
        item_subtype: "CashTransaction",
        item_id: 123,
        event: :update,
        mutation_source: :web,
        object_changes: { "description" => %w[Before After] },
        metadata: {}
      )
      message.update!(auto_applied: false, audit_operation: operation)
      allow(Audit::Rollback::Preview).to receive(:new).and_return(instance_double(Audit::Rollback::Preview, state: "previewable"))

      expect(service.revertible?).to be(true)
    end
  end
end
