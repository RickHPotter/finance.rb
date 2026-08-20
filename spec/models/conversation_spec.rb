# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "[ business logic ]" do
    let(:rikki) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:gigi) { create(:user, first_name: "Gigi", email: "gigi@example.com") }

    it "finds or creates a single human conversation between the same two users" do
      first = described_class.find_or_create_human_between!(rikki, gigi)
      second = described_class.find_or_create_human_between!(rikki, gigi)

      expect(first).to eq(second)
      expect(first.kind).to eq("human")
    end

    it "finds or creates a single shared assistant conversation between the same two users" do
      first = described_class.find_or_create_assistant_between!(rikki, gigi)
      second = described_class.find_or_create_assistant_between!(gigi, rikki)

      expect(first).to eq(second)
      expect(first.kind).to eq("assistant")
    end

    it "keeps conversations distinct across scenario keys" do
      main = described_class.find_or_create_human_between!(rikki, gigi)
      scenario = described_class.find_or_create_human_between!(rikki, gigi, scenario_key: "scenario-1")

      expect(main).not_to eq(scenario)
      expect(main.scenario_key).to be_nil
      expect(scenario.scenario_key).to eq("scenario-1")
    end

    it "reuses the same scenario-scoped assistant conversation for the same key" do
      first = described_class.find_or_create_assistant_between!(rikki, gigi, scenario_key: "scenario-1")
      second = described_class.find_or_create_assistant_between!(gigi, rikki, scenario_key: "scenario-1")

      expect(first).to eq(second)
      expect(first.scenario_key).to eq("scenario-1")
    end

    it "assigns an immutable public id and resolves it without exposing the numeric id" do
      conversation = described_class.find_or_create_human_between!(rikki, gigi)

      expect(conversation.public_id).to match(/\A[0-9a-f-]{36}\z/)
      expect(described_class.find_by_public_id!(conversation.public_id)).to eq(conversation)

      original_public_id = conversation.public_id
      expect { conversation.update!(public_id: SecureRandom.uuid) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect(conversation.reload.public_id).to eq(original_public_id)
    end

    it "accepts canonical identity only when exactly the friendship users participate" do
      friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
      canonical = described_class.new(friendship:, kind: :human)
      canonical.conversation_participants.build(user: rikki)
      canonical.conversation_participants.build(user: gigi)

      outsider = create(:user, :random)
      missing = described_class.new(friendship:, kind: :assistant)
      missing.conversation_participants.build(user: rikki)
      substituted = described_class.new(friendship:, kind: :assistant)
      substituted.conversation_participants.build(user: rikki)
      substituted.conversation_participants.build(user: outsider)
      extra = described_class.new(friendship:, kind: :assistant)
      extra.conversation_participants.build(user: rikki)
      extra.conversation_participants.build(user: gigi)
      extra.conversation_participants.build(user: outsider)

      expect(canonical).to be_valid
      expect([ missing, substituted, extra ]).to all(be_invalid)
      expect([ missing, substituted, extra ].map { |conversation| conversation.errors[:conversation_participants] }).to all(be_present)
    end

    it "does not allow a canonical conversation to change friendships" do
      friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
      conversation = described_class.new(friendship:, kind: :human)
      conversation.conversation_participants.build(user: rikki)
      conversation.conversation_participants.build(user: gigi)
      conversation.save!
      other_friendship = create(:friendship, :accepted, user: rikki, friend: create(:user, :random))

      expect(conversation.update(friendship: other_friendship)).to be(false)
      expect(conversation.errors[:friendship]).to be_present
    end

    it "enforces canonical main and scenario uniqueness in PostgreSQL" do
      friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
      create_canonical_conversation(friendship:, users: [ rikki, gigi ], kind: :human)

      duplicate = described_class.new(friendship:, kind: :human)
      duplicate.conversation_participants.build(user: rikki)
      duplicate.conversation_participants.build(user: gigi)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { create_canonical_conversation(friendship:, users: [ rikki, gigi ], kind: :assistant) }.not_to raise_error
      expect { create_canonical_conversation(friendship:, users: [ rikki, gigi ], kind: :human, scenario_key: SecureRandom.uuid) }.not_to raise_error
    end
  end

  def create_canonical_conversation(friendship:, users:, kind:, scenario_key: nil)
    described_class.new(friendship:, kind:, scenario_key:).tap do |conversation|
      users.each { |user| conversation.conversation_participants.build(user:) }
      conversation.save!
    end
  end
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id            :bigint           not null, primary key
#  kind          :string           default("human"), not null, indexed, uniquely indexed => [friendship_id], uniquely indexed => [friendship_id, scenario_key]
#  scenario_key  :string           uniquely indexed => [friendship_id, kind], indexed
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  friendship_id :bigint           indexed, uniquely indexed => [kind], uniquely indexed => [kind, scenario_key]
#  public_id     :uuid             not null, uniquely indexed
#
# Indexes
#
#  index_conversations_on_friendship_id                (friendship_id)
#  index_conversations_on_kind                         (kind)
#  index_conversations_on_main_canonical_identity      (friendship_id,kind) UNIQUE WHERE ((friendship_id IS NOT NULL) AND (scenario_key IS NULL))
#  index_conversations_on_public_id                    (public_id) UNIQUE
#  index_conversations_on_scenario_canonical_identity  (friendship_id,kind,scenario_key) UNIQUE WHERE ((friendship_id IS NOT NULL) AND (scenario_key IS NOT NULL))
#  index_conversations_on_scenario_key                 (scenario_key)
#
# Foreign Keys
#
#  fk_rails_...  (friendship_id => friendships.id)
#
