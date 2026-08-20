# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageAction, type: :model do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { resolve_assistant_conversation(sender, recipient) }
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

# == Schema Information
#
# Table name: message_actions
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  action               :string           not null, uniquely indexed => [message_id]
#  error_code           :string
#  initiator            :string           not null
#  metadata             :jsonb            not null
#  outcome              :string           not null
#  resulting_state      :string           not null
#  scenario_key         :uuid
#  created_at           :datetime         not null, indexed => [actor_id], indexed => [conversation_id], indexed => [recipient_context_id]
#  actor_id             :bigint           not null, indexed, indexed => [created_at]
#  audit_operation_id   :uuid             indexed
#  conversation_id      :bigint           not null, indexed, indexed => [created_at]
#  friend_id            :bigint           not null, indexed
#  friendship_id        :bigint           not null, indexed
#  message_id           :bigint           not null, indexed, uniquely indexed => [action]
#  recipient_context_id :bigint           not null, indexed, indexed => [created_at]
#
# Indexes
#
#  index_message_actions_on_actor_id                             (actor_id)
#  index_message_actions_on_actor_id_and_created_at              (actor_id,created_at)
#  index_message_actions_on_audit_operation_id                   (audit_operation_id)
#  index_message_actions_on_conversation_id                      (conversation_id)
#  index_message_actions_on_conversation_id_and_created_at       (conversation_id,created_at)
#  index_message_actions_on_friend_id                            (friend_id)
#  index_message_actions_on_friendship_id                        (friendship_id)
#  index_message_actions_on_message_id                           (message_id)
#  index_message_actions_on_recipient_context_id                 (recipient_context_id)
#  index_message_actions_on_recipient_context_id_and_created_at  (recipient_context_id,created_at)
#  index_message_actions_on_successful_effect                    (message_id,action) UNIQUE WHERE ((outcome)::text = 'succeeded'::text)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => restrict
#  fk_rails_...  (audit_operation_id => audit_operations.id) ON DELETE => restrict
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => restrict
#  fk_rails_...  (friend_id => users.id) ON DELETE => restrict
#  fk_rails_...  (friendship_id => friendships.id) ON DELETE => restrict
#  fk_rails_...  (message_id => messages.id) ON DELETE => restrict
#  fk_rails_...  (recipient_context_id => contexts.id) ON DELETE => restrict
#
