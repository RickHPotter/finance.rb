# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Messages::Respond do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { resolve_assistant_conversation(sender, recipient) }

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  it "acknowledges once and records a repeated acknowledgement as idempotent" do
    message = conversation.messages.create!(
      user: sender,
      body: "notification:paid_state",
      headers: { version: "message_paid_state_v1", event: { action: "paid", details: {} } }.to_json
    )
    service = described_class.new(message:, actor: recipient, context: recipient.main_context, action: :acknowledge)

    expect(service.call).to be_succeeded
    expect(service.call).to be_idempotent
    expect(message.reload).to be_applied
    expect(message.message_actions.pluck(:outcome)).to eq(%w[succeeded idempotent])
  end

  it "rejects once and leaves a repeated rejection idempotent" do
    message = conversation.messages.create!(
      user: sender,
      body: "notification:create",
      headers: {
        version: "message_notification_v2",
        event: { action: "create", transaction_type: "CashTransaction", details: {} },
        replay: { id: 123, type: "CashTransaction" }
      }.to_json
    )
    service = described_class.new(message:, actor: recipient, context: recipient.main_context, action: :reject)

    expect(service.call).to be_succeeded
    expect(service.call).to be_idempotent
    expect(message.reload.workflow_state).to eq("rejected")
    expect(message.message_actions.pluck(:outcome)).to eq(%w[succeeded idempotent])
  end

  it "denies responses to human messages without trying to create an action event" do
    message = conversation.messages.create!(user: sender, body: "Hello")

    result = described_class.new(
      message:,
      actor: recipient,
      context: recipient.main_context,
      action: :reject
    ).call

    expect(result).to have_attributes(status: :denied, error_code: "state_unavailable")
    expect(message.message_actions).to be_empty
  end
end
