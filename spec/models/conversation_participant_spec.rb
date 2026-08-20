# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConversationParticipant, type: :model do
  let(:rikki) { create(:user, :random) }
  let(:gigi) { create(:user, :random) }
  let(:friendship) { create(:friendship, :accepted, user: rikki, friend: gigi) }
  let(:conversation) { Logic::Conversations::Resolve.call(actor: rikki, friendship:, kind: :human) }
  let(:rikki_participant) { conversation.participant_for!(rikki) }
  let(:gigi_participant) { conversation.participant_for!(gigi) }

  it "tracks archive and mute state independently for each participant" do
    rikki_participant.update!(archived_at: Time.current, muted_at: Time.current)

    expect(rikki_participant).to be_archived
    expect(rikki_participant).to be_muted
    expect(gigi_participant).not_to be_archived
    expect(gigi_participant).not_to be_muted
  end

  it "counts only nonsuperseded incoming messages newer than its cursor" do
    predecessor = conversation.messages.create!(user: gigi, body: "Old")
    replacement = conversation.messages.create!(user: gigi, body: "Current")
    mine = conversation.messages.create!(user: rikki, body: "Mine")
    predecessor.update!(superseded_by: replacement)

    expect(rikki_participant.unread_count).to eq(1)

    rikki_participant.advance_read_cursor_to!(replacement)

    expect(rikki_participant.reload.last_read_message).to eq(replacement)
    expect(rikki_participant.unread_count).to eq(0)
    expect(gigi_participant.unread_count).to eq(1)
    expect(gigi_participant.unread_messages).to contain_exactly(mine)
  end

  it "never moves its read cursor backwards" do
    first = conversation.messages.create!(user: gigi, body: "First")
    second = conversation.messages.create!(user: gigi, body: "Second")

    rikki_participant.advance_read_cursor_to!(second)
    rikki_participant.advance_read_cursor_to!(first)

    expect(rikki_participant.reload.last_read_message).to eq(second)
  end

  it "rejects a cursor from another conversation" do
    third_user = create(:user, :random)
    other_friendship = create(:friendship, :accepted, user: rikki, friend: third_user)
    other_conversation = Logic::Conversations::Resolve.call(actor: rikki, friendship: other_friendship, kind: :human)
    other_message = other_conversation.messages.create!(user: third_user, body: "Elsewhere")

    expect { rikki_participant.update!(last_read_message: other_message) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { rikki_participant.advance_read_cursor_to!(other_message) }.to raise_error(ArgumentError)
  end

  it "reactivates both participants when either one sends a new message" do
    rikki_participant.update!(archived_at: Time.current)
    gigi_participant.update!(archived_at: Time.current)

    conversation.messages.create!(user: gigi, body: "We are back")

    expect(rikki_participant.reload).not_to be_archived
    expect(gigi_participant.reload).not_to be_archived
  end

  it "suppresses push attention for a muted recipient without suppressing storage or unread state" do
    create(:push_subscription, user: rikki)
    rikki_participant.update!(muted_at: Time.current)
    allow(WebPush).to receive(:payload_send)
    allow(ActionCable.server).to receive(:broadcast).and_call_original

    message = conversation.messages.create!(user: gigi, body: "Quiet delivery")
    message.send(:send_email)

    expect(message).to be_persisted
    expect(rikki_participant.unread_count).to eq(1)
    expect(WebPush).not_to have_received(:payload_send)
    expect(ActionCable.server).to have_received(:broadcast)
  end

  it "delivers push attention to an unmuted recipient only" do
    recipient_subscription = create(:push_subscription, user: rikki)
    create(:push_subscription, user: gigi)
    allow(WebPush).to receive(:payload_send)

    message = conversation.messages.create!(user: gigi, body: "Attention delivery")
    message.send(:send_email)

    expect(WebPush).to have_received(:payload_send).once.with(hash_including(endpoint: recipient_subscription.endpoint))
  end
end
