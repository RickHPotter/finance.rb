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
  end
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id         :bigint           not null, primary key
#  kind       :string           default("human"), not null, indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_conversations_on_kind  (kind)
#
