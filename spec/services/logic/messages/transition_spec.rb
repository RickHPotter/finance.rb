# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Messages::Transition do
  let(:sender) { create(:user, :random) }
  let(:receiver) { create(:user, :random) }
  let(:conversation) do
    Conversation.create!.tap do |record|
      record.conversation_participants.create!(user: sender)
      record.conversation_participants.create!(user: receiver)
    end
  end
  let(:headers) do
    {
      version: "message_notification_v2",
      event: { action: "create", transaction_type: "CashTransaction", details: {} },
      replay: { id: 123, type: "CashTransaction" }
    }.to_json
  end

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  def actionable_message(**attributes)
    conversation.messages.create!({ user: sender, body: "notification:create", headers: }.merge(attributes))
  end

  it "centralizes successful apply and revert timestamp compatibility" do
    message = actionable_message

    described_class.call(message, :apply, auto_applied: true)

    expect(message).to have_attributes(action_state: "accepted", applied_at: be_present, auto_applied: true)
    expect(message).to be_applied
    expect(message).to be_action_state_compatible_with_legacy

    described_class.call(message, :revert)

    expect(message).to have_attributes(action_state: "reverted", reverted_at: be_present)
    expect(message).to be_reverted
    expect(message).to be_action_state_compatible_with_legacy
  end

  it "supports every bounded pending outcome and retrying a failure" do
    rejected = actionable_message
    failed = actionable_message
    unavailable = actionable_message

    described_class.call(rejected, :reject)
    described_class.call(failed, :fail)
    described_class.call(unavailable, :unavailable)

    expect(rejected.action_state).to eq("rejected")
    expect(failed.action_state).to eq("failed")
    expect(unavailable.action_state).to eq("unavailable")

    described_class.call(failed, :apply)
    expect(failed).to have_attributes(action_state: "accepted", applied_at: be_present)
  end

  it "expires pending predecessors without rewriting accepted history" do
    pending = actionable_message
    accepted = actionable_message(applied_at: 1.hour.ago)
    successor = actionable_message

    described_class.expire_scope!(Message.where(id: [ pending.id, accepted.id ]), superseded_by: successor)

    expect(pending.reload).to have_attributes(action_state: "expired", superseded_by_id: successor.id)
    expect(accepted.reload).to have_attributes(action_state: "accepted", superseded_by_id: successor.id)
  end

  it "acknowledges an auto-applied message without replacing its application timestamp" do
    applied_at = 1.hour.ago
    message = actionable_message(applied_at:, auto_applied: true)

    described_class.call(message, :acknowledge)

    expect(message.applied_at).to be_within(1.second).of(applied_at)
    expect(message.read_at).to be_present
    expect(message.action_state).to eq("accepted")
  end

  it "rejects invalid transitions and human action state" do
    human = conversation.messages.create!(user: sender, body: "Hello")
    accepted = actionable_message(applied_at: Time.current)

    expect { described_class.call(human, :apply) }.to raise_error(described_class::InvalidTransition, /Human messages/)
    expect { described_class.call(accepted, :reject) }.to raise_error(described_class::InvalidTransition, /Cannot reject/)
  end
end
