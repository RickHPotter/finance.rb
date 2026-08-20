# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Page do
  let(:user) { create(:user, :random) }
  let(:timestamp) { Time.zone.local(2026, 8, 20, 12) }

  def conversation_with(friend:, kind: :human, scenario_key: nil, activity_at: timestamp)
    create(:friendship, :accepted, user:, friend:)
    create(:context, user: friend, scenario_key:) if scenario_key.present?
    conversation = public_send("resolve_#{kind}_conversation", user, friend, scenario_key:)
    conversation.update_columns(last_message_at: activity_at)
    conversation
  end

  it "orders equal activity timestamps by id and keeps new activity from shifting the older page" do
    oldest = conversation_with(friend: create(:user, :random), activity_at: timestamp - 2.hours)
    tied_low = conversation_with(friend: create(:user, :random))
    tied_high = conversation_with(friend: create(:user, :random))

    first_page = described_class.call(scope: user.conversations, size: 2)
    inserted = conversation_with(friend: create(:user, :random), activity_at: timestamp + 1.hour)
    second_page = described_class.call(scope: user.conversations, cursor: first_page.next_cursor, size: 2)

    expect(first_page.records).to eq([ tied_high, tied_low ])
    expect(second_page.records).to eq([ oldest ])
    expect(first_page.records + second_page.records).not_to include(inserted)
  end

  it "keeps kind and scenario filters inside the current cursor scope" do
    human = conversation_with(friend: create(:user, :random), kind: :human)
    assistant = conversation_with(friend: create(:user, :random), kind: :assistant, activity_at: timestamp + 1.hour)
    scenario_key = SecureRandom.uuid
    create(:context, user:, scenario_key:)
    derived = conversation_with(friend: create(:user, :random), kind: :human, scenario_key:, activity_at: timestamp + 2.hours)

    page = described_class.call(scope: user.conversations.human.for_scenario(nil), size: 1)

    expect(page.records).to eq([ human ])
    expect(page.records).not_to include(assistant, derived)
  end
end
