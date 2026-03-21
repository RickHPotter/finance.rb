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

    it "creates separate assistant conversations for each receiver" do
      first = described_class.find_or_create_assistant_between!(sender: rikki, receiver: gigi)
      second = described_class.find_or_create_assistant_between!(sender: gigi, receiver: rikki)

      expect(first).not_to eq(second)
      expect(first.kind).to eq("assistant")
      expect(first.assistant_owner).to eq(gigi)
      expect(second.assistant_owner).to eq(rikki)
    end
  end
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  kind               :string           default("human"), not null, indexed => [assistant_owner_id]
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  assistant_owner_id :bigint           indexed, indexed => [kind]
#
# Indexes
#
#  index_conversations_on_assistant_owner_id           (assistant_owner_id)
#  index_conversations_on_kind_and_assistant_owner_id  (kind,assistant_owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (assistant_owner_id => users.id)
#
