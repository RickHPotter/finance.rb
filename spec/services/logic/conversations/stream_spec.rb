# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Stream do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { resolve_human_conversation(sender, recipient) }

  it "issues distinct participant stream identities only inside the authorized scenario" do
    sender_stream = described_class.for(conversation:, actor: sender, context: sender.main_context)
    recipient_stream = described_class.for(conversation:, actor: recipient, context: recipient.main_context)

    expect(sender_stream).to eq([ conversation, "participant", conversation.participant_for!(sender) ])
    expect(recipient_stream).to eq([ conversation, "participant", conversation.participant_for!(recipient) ])
    expect(sender_stream).not_to eq(recipient_stream)
  end

  it "denies outsiders, wrong scenarios, and every revoked friendship state" do
    outsider = create(:user, :random)
    derived_context = create(:context, user: sender, source_context: sender.main_context)

    expect { described_class.for(conversation:, actor: outsider, context: outsider.main_context) }
      .to raise_error(Logic::Conversations::Policy::AccessDenied)
    expect { described_class.for(conversation:, actor: sender, context: derived_context) }
      .to raise_error(Logic::Conversations::Policy::AccessDenied)

    %w[blocked removed].each do |state|
      friendship.update_columns(state:)
      expect { described_class.for(conversation:, actor: sender, context: sender.main_context) }
        .to raise_error(Logic::Conversations::Policy::AccessDenied)
    end
  end
end
