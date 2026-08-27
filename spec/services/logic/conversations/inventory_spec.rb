# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Inventory do
  let(:rikki) { create(:user, :random) }
  let(:gigi) { create(:user, :random) }

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  def create_conversation(*users, kind: :human, scenario_key: nil, friendship: nil)
    Conversation.new(kind:, scenario_key:, friendship:).tap do |conversation|
      users.each { |user| conversation.conversation_participants.build(user:) }
      conversation.save!
    end
  end

  def accepted_friendship(user = rikki, friend = gigi)
    create(:friendship, :accepted, user:, friend:)
  end

  def issue(report, code, record_id = nil)
    report.issues.find do |entry|
      entry.code == code && (record_id.nil? || entry.record_ids.include?(record_id))
    end
  end

  it "reports a reversed clean pair without changing conversation or message history" do
    friendship = accepted_friendship
    conversation = create_conversation(gigi, rikki, friendship:)
    message = conversation.messages.create!(user: rikki, body: "Hello")
    timestamps = [ conversation.updated_at, message.updated_at ]

    report = described_class.new.call

    expect(report).to be_clean
    expect(report).to have_attributes(conversation_count: 1, message_count: 1)
    expect([ conversation.reload.updated_at, message.reload.updated_at ]).to eq(timestamps)
  end

  it "reports legacy rows that have not been assigned to their accepted friendship" do
    friendship = accepted_friendship
    conversation = create_conversation(gigi, rikki)

    report = described_class.new.call

    expect(issue(report, "unassigned_friendship", conversation.id).details).to include(
      user_ids: contain_exactly(rikki.id, gigi.id),
      expected_friendship_id: friendship.id
    )
  end

  it "reports a persisted friendship that does not match the participant pair" do
    expected_friendship = accepted_friendship
    other_user = create(:user, :random)
    other_friendship = create(:friendship, :accepted, user: rikki, friend: other_user)
    conversation = create_conversation(gigi, rikki)
    conversation.friendship_id = other_friendship.id

    report = described_class.new(conversation_scope: [ conversation ], message_scope: []).call

    expect(issue(report, "friendship_mismatch", conversation.id).details).to include(
      user_ids: contain_exactly(rikki.id, gigi.id),
      friendship_id: other_friendship.id,
      expected_friendship_id: expected_friendship.id
    )
  end

  it "inventories malformed participant, canonical thread, friendship, and scenario shapes with concrete ids" do
    accepted_friendship
    first = create_conversation(rikki, gigi, kind: :assistant)
    duplicate = create_conversation(gigi, rikki, kind: :assistant)
    zero_participants = create_conversation
    one_participant = create_conversation(rikki)
    third_user = create(:user, :random)
    three_participants = create_conversation(rikki, gigi, third_user)
    user_without_friendship = create(:user, :random)
    missing_friendship = create_conversation(rikki, user_without_friendship)
    scenario_key = SecureRandom.uuid
    create(:context, user: rikki, scenario_key:)
    missing_scenario = create_conversation(rikki, gigi, scenario_key:)

    report = described_class.new.call

    expect(issue(report, "duplicate_canonical_thread").record_ids).to contain_exactly(first.id, duplicate.id)
    expect(issue(report, "invalid_participant_count", zero_participants.id).details[:participant_count]).to eq(0)
    expect(issue(report, "invalid_participant_count", one_participant.id).details[:participant_count]).to eq(1)
    expect(issue(report, "invalid_participant_count", three_participants.id).details[:participant_count]).to eq(3)
    expect(issue(report, "missing_friendship", missing_friendship.id).details[:user_ids]).to contain_exactly(rikki.id, user_without_friendship.id)
    expect(issue(report, "missing_scenario", missing_scenario.id).details[:missing_user_ids]).to eq([ gigi.id ])
  end

  it "identifies a legacy duplicate membership even after the database guard is installed" do
    accepted_friendship
    conversation = create_conversation(rikki, gigi)
    conversation.conversation_participants.load
    duplicate = conversation.conversation_participants.build(id: -1, user: rikki)

    report = described_class.new(conversation_scope: [ conversation ], message_scope: []).call

    expect(issue(report, "duplicate_participant", duplicate.id).details).to include(
      conversation_id: conversation.id,
      user_id: rikki.id,
      count: 2
    )
  end

  it "reports invalid payloads and contradictory legacy action facts without rejecting valid historical combinations" do
    accepted_friendship
    conversation = create_conversation(rikki, gigi, kind: :assistant)
    malformed = conversation.messages.create!(user: rikki, body: "Malformed")
    malformed.update_columns(headers: "{not-json")
    missing_replay = conversation.messages.create!(user: rikki, body: "notification:update")
    missing_replay.update_columns(headers: { version: "message_notification_v2", event: { action: "update" }, replay: nil }.to_json)
    contradictory_human = conversation.messages.create!(user: rikki, body: "Human with action", auto_applied: true)
    valid_reverted = conversation.messages.create!(user: rikki, body: "notification:create")
    valid_reverted.update_columns(
      headers: { version: "message_notification_v2", event: { action: "create" }, replay: { id: 123, type: "CashTransaction" } }.to_json,
      applied_at: 2.hours.ago,
      reverted_at: 1.hour.ago
    )
    paid_state = conversation.messages.create!(user: rikki, body: "notification:paid_state", read_at: nil)
    paid_state.update_columns(headers: { version: "message_paid_state_v1", event: { action: "paid" } }.to_json)

    report = described_class.new.call

    expect(issue(report, "invalid_message_payload", malformed.id).details[:reasons]).to eq([ "malformed_json" ])
    expect(issue(report, "invalid_message_payload", missing_replay.id).details[:reasons]).to eq([ "missing_replay" ])
    expect(issue(report, "action_state_contradiction", contradictory_human.id).details[:reasons]).to contain_exactly(
      "human_with_action_facts", "auto_applied_without_applied"
    )
    expect(issue(report, "action_state_contradiction", valid_reverted.id)).to be_nil
  end

  it "renders an operator-readable report with issue types and record ids" do
    conversation = create_conversation

    text = described_class.new.call.to_text

    expect(text).to include("Conversation/message inventory", "Issues: 1")
    expect(text).to include("[invalid_participant_count] Conversation ids=#{conversation.id}")
  end
end
