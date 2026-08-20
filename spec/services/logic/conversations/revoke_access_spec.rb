# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::RevokeAccess do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { Conversation.find_or_create_assistant_between!(sender, recipient) }

  before do
    allow(ActionableMessageAutoApplyJob).to receive(:perform_now)
    allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
  end

  def actionable_message(action_state: nil, applied_at: nil)
    conversation.messages.create!(
      user: sender,
      body: "notification:create",
      action_state:,
      applied_at:,
      headers: {
        version: "message_notification_v2",
        event: { action: "create", transaction_type: "CashTransaction", details: {} },
        replay: { id: 123, type: "CashTransaction" }
      }.to_json
    )
  end

  it "makes pending and failed actions unavailable while preserving applied financial state and history" do
    pending_message = actionable_message
    failed_message = actionable_message
    Logic::Messages::Transition.call(failed_message, :fail)
    accepted_message = actionable_message(action_state: "accepted", applied_at: Time.current)

    friendship.update!(state: "blocked")

    expect(pending_message.reload.workflow_state).to eq("unavailable")
    expect(failed_message.reload.workflow_state).to eq("unavailable")
    expect(accepted_message.reload.workflow_state).to eq("accepted")
    expect(conversation.messages).to contain_exactly(pending_message, failed_message, accepted_message)
    expect(Logic::Conversations::Policy.scope(user: recipient, context: recipient.main_context)).to be_empty
    expect(pending_message.message_actions.last).to have_attributes(
      action: "apply",
      initiator: "system",
      outcome: "denied",
      resulting_state: "unavailable",
      error_code: "friendship_unavailable"
    )
  end

  it "restores the same canonical thread identities without reviving unavailable actions" do
    human_conversation = Conversation.find_or_create_human_between!(sender, recipient)
    pending_message = actionable_message

    friendship.update!(state: "removed")
    friendship.update!(state: "accepted")

    expect(Conversation.find_or_create_human_between!(sender, recipient)).to eq(human_conversation)
    expect(Conversation.find_or_create_assistant_between!(sender, recipient)).to eq(conversation)
    expect(pending_message.reload.workflow_state).to eq("unavailable")
  end

  it "removes every open canonical conversation surface after revocation" do
    human_conversation = Conversation.find_or_create_human_between!(sender, recipient)
    assistant_conversation = conversation

    friendship.update!(state: "blocked")

    [ assistant_conversation, human_conversation ].each do |revoked_conversation|
      revoked_conversation.conversation_participants.each do |participant|
        streamables = Logic::Conversations::Stream.for_participant(conversation: revoked_conversation, participant:)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to).with(*streamables, target: "center_container")
      end
    end
  end

  it "does not broadcast a message created after persisted access has been revoked" do
    assistant_conversation = conversation
    friendship.update_columns(state: "blocked")
    expect_any_instance_of(Message).not_to receive(:broadcast_to_conversation)

    assistant_conversation.messages.create!(user: sender, body: "Retained but not streamed")
  end
end
