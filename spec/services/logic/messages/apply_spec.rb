# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Messages::Apply do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { Conversation.find_or_create_assistant_between!(sender, recipient) }
  let(:message) { build_message }
  let(:target) { recipient.main_context.cash_transactions.new(user: recipient) }

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  def build_message(action: "create", replay: { id: 123, type: "CashTransaction" })
    conversation.messages.create!(
      user: sender,
      body: "notification:#{action}",
      headers: {
        version: "message_notification_v2",
        event: { action:, transaction_type: "CashTransaction", details: {} },
        replay:
      }.to_json
    )
  end

  def service(actor: recipient, context: recipient.main_context, initiator: :manual, target: self.target, source_message: message)
    described_class.new(message: source_message, actor:, context:, initiator:, target:)
  end

  it "applies once and records subsequent delivery as idempotent" do
    mutations = 0

    first = service.call do
      mutations += 1
      true
    end
    second = service.call do
      mutations += 1
      true
    end

    expect(first).to be_succeeded
    expect(second).to be_idempotent
    expect(mutations).to eq(1)
    expect(message.reload).to be_applied
    expect(message.message_actions.order(:id).pluck(:action, :outcome)).to eq([ %w[apply succeeded], %w[apply idempotent] ])
  end

  it "captures the complete successful action identity and resulting operation" do
    result = nil

    Audit::Operation.run(source: :web, actor: recipient, context: recipient.main_context) do
      result = service.call { true }
    end

    event = result.message_action
    expect(event).to have_attributes(
      message:,
      conversation:,
      friendship:,
      actor: recipient,
      friend: sender,
      recipient_context: recipient.main_context,
      initiator: "manual",
      outcome: "succeeded",
      resulting_state: "accepted",
      audit_operation: result.audit_operation
    )
  end

  it "denies a wrong actor and wrong scenario before mutation" do
    derived_context = create(:context, user: recipient, source_context: recipient.main_context, name: "Wrong apply scenario")
    mutations = 0

    wrong_actor = service(actor: sender, context: sender.main_context).call do
      mutations += 1
      true
    end
    wrong_context = service(context: derived_context).call do
      mutations += 1
      true
    end

    expect(wrong_actor).to have_attributes(status: :denied, error_code: "wrong_recipient")
    expect(wrong_context).to have_attributes(status: :denied, error_code: "wrong_context")
    expect(mutations).to eq(0)
  end

  it "marks validation failure as retryable and succeeds once corrected" do
    failed = service.call { false }
    retried = service.call { true }

    expect(failed).to have_attributes(status: :failed, error_code: "validation_failed")
    expect(retried).to be_succeeded
    expect(message.reload).to be_applied
    expect(message.message_actions.pluck(:outcome)).to contain_exactly("failed", "succeeded")
  end

  it "marks an automatic update with no local reference unavailable" do
    update_message = build_message(action: "update", replay: { id: 999_999, type: "CashTransaction" })

    result = service(initiator: :automatic, target: nil, source_message: update_message).call { true }

    expect(result).to have_attributes(status: :denied, error_code: "local_reference_unavailable")
    expect(update_message.reload.workflow_state).to eq("unavailable")
  end
end
