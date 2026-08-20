# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageAction, type: :model do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { Conversation.find_or_create_assistant_between!(sender, recipient) }
  let(:message) { conversation.messages.create!(user: sender, body: "notification:paid_state", headers: paid_state_headers.to_json) }
  let(:paid_state_headers) { { version: "message_paid_state_v1", event: { action: "paid", details: {} } } }
  let!(:message_action) do
    described_class.create!(
      message:,
      conversation:,
      friendship:,
      actor: recipient,
      friend: sender,
      recipient_context: recipient.main_context,
      action: :acknowledge,
      initiator: :manual,
      outcome: :succeeded,
      resulting_state: :accepted
    )
  end

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  it "is readonly in the model and rejects PostgreSQL updates" do
    expect(message_action).to be_readonly
    expect { described_class.where(id: message_action.id).update_all(error_code: "changed") }
      .to raise_error(ActiveRecord::StatementInvalid, /message_actions is append-only/)
  end

  it "rejects PostgreSQL deletes" do
    expect { described_class.where(id: message_action.id).delete_all }
      .to raise_error(ActiveRecord::StatementInvalid, /message_actions is append-only/)
  end
end
