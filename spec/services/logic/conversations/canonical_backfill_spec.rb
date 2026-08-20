# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::CanonicalBackfill do
  let(:rikki) { create(:user, :random) }
  let(:gigi) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: rikki, friend: gigi) }

  before { allow(ActionableMessageAutoApplyJob).to receive(:perform_now) }

  def create_legacy_conversation(*users, kind: :human, scenario_key: nil)
    Conversation.create!(kind:, scenario_key:).tap do |conversation|
      users.each { |user| conversation.conversation_participants.create!(user:) }
    end
  end

  it "plans without writing, then consolidates reversed duplicates into the oldest canonical conversation" do
    canonical = create_legacy_conversation(rikki, gigi, kind: :assistant)
    duplicate = create_legacy_conversation(gigi, rikki, kind: :assistant)
    operation = AuditOperation.create!(source: :web, result: :committed, actor_id: rikki.id, context_id: rikki.main_context.id)
    reference = create(:cash_transaction, user: rikki, context: rikki.main_context)
    predecessor = canonical.messages.create!(user: rikki, body: "First", reference_transactable: reference, audit_operation: operation)
    replacement = duplicate.messages.create!(user: rikki, body: "Second", reference_transactable: reference, audit_operation: operation)
    predecessor.update!(superseded_by: replacement)
    original_public_id = canonical.public_id

    planned = described_class.new.call

    expect(planned).to have_attributes(status: "planned")
    expect(planned.actions.sole).to have_attributes(
      canonical_conversation_id: canonical.id,
      duplicate_conversation_ids: [ duplicate.id ],
      friendship_id: friendship.id,
      message_ids: [ replacement.id ]
    )
    expect(canonical.reload.friendship_id).to be_nil
    expect(duplicate).to be_persisted

    result = described_class.new(apply: true).call

    expect(result).to be_applied
    expect(canonical.reload).to have_attributes(friendship_id: friendship.id, public_id: original_public_id)
    expect(Conversation).not_to exist(duplicate.id)
    expect(canonical.messages.order(:id).ids).to eq([ predecessor.id, replacement.id ])
    expect(predecessor.reload.superseded_by).to eq(replacement)
    expect(replacement.reload).to have_attributes(conversation_id: canonical.id, audit_operation_id: operation.id)
    expect(replacement.reference_transactable).to eq(reference)
  end

  it "keeps human, assistant, main, and derived identities separate" do
    scenario_key = SecureRandom.uuid
    create(:context, user: rikki, scenario_key:)
    create(:context, user: gigi, scenario_key:)
    main_human = create_legacy_conversation(rikki, gigi, kind: :human)
    main_assistant = create_legacy_conversation(rikki, gigi, kind: :assistant)
    derived_human = create_legacy_conversation(rikki, gigi, kind: :human, scenario_key:)

    result = described_class.new(apply: true).call

    expect(result.actions.map { |action| [ action.kind, action.scenario_key ] }).to contain_exactly(
      [ "human", nil ], [ "assistant", nil ], [ "human", scenario_key ]
    )
    expect([ main_human, main_assistant, derived_human ].map { |conversation| conversation.reload.friendship_id }).to all(eq(friendship.id))
  end

  it "reports and leaves ambiguous participant, friendship, and scenario histories untouched" do
    one_participant = create_legacy_conversation(rikki)
    stranger = create(:user, :random)
    missing_friendship = create_legacy_conversation(rikki, stranger)
    scenario_key = SecureRandom.uuid
    create(:context, user: rikki, scenario_key:)
    missing_scenario = create_legacy_conversation(rikki, gigi, scenario_key:)

    result = described_class.new(apply: true).call

    expect(result.issues.map(&:code)).to include("invalid_participant_count", "missing_friendship", "missing_scenario")
    expect([ one_participant, missing_friendship, missing_scenario ].map { |conversation| conversation.reload.friendship_id }).to all(be_nil)
    expect(Conversation.where(id: [ one_participant.id, missing_friendship.id, missing_scenario.id ]).count).to eq(3)
  end

  it "is idempotent after canonical rows have been attached and duplicates removed" do
    conversation = create_legacy_conversation(rikki, gigi)

    first = described_class.new(apply: true).call
    second = described_class.new(apply: true).call

    expect(first).to be_applied
    expect(second).to be_applied
    expect(second.actions).to be_empty
    expect(conversation.reload.friendship).to eq(friendship)
    expect(Conversation.where(friendship:).count).to eq(1)
  end
end
