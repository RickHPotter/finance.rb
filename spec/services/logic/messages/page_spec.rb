# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Messages::Page do
  let(:sender) { create(:user, :random) }
  let(:recipient) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user: sender, friend: recipient) }
  let(:conversation) { resolve_human_conversation(sender, recipient) }
  let(:timestamp) { Time.zone.local(2026, 8, 20, 12) }

  it "retrieves by creation time and id while rendering each page chronologically" do
    oldest = conversation.messages.create!(user: sender, body: "Oldest", created_at: timestamp - 1.hour)
    tied_low = conversation.messages.create!(user: sender, body: "Tied low", created_at: timestamp)
    tied_high = conversation.messages.create!(user: sender, body: "Tied high", created_at: timestamp)

    first_page = described_class.call(scope: conversation.messages, size: 2)
    inserted = conversation.messages.create!(user: sender, body: "Inserted", created_at: timestamp + 1.hour)
    older_page = described_class.call(scope: conversation.messages, cursor: first_page.next_cursor, size: 2)

    expect(first_page.records).to eq([ tied_low, tied_high ])
    expect(older_page.records).to eq([ oldest ])
    expect(older_page.records + first_page.records).not_to include(inserted)
  end

  it "fills a bounded page after applying an in-memory visibility selector" do
    hidden = conversation.messages.create!(user: sender, body: "Hidden", created_at: timestamp)
    visible = conversation.messages.create!(user: sender, body: "Visible", created_at: timestamp - 1.minute)

    page = described_class.call(scope: conversation.messages, size: 1, selector: ->(message) { message != hidden })

    expect(page.records).to eq([ visible ])
  end
end
