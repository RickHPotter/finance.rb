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
  end
end

# == Schema Information
#
# Table name: conversations
# Database name: primary
#
#  id           :bigint           not null, primary key
#  kind         :string           default("human"), not null, indexed
#  scenario_key :string           indexed
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_conversations_on_kind          (kind)
#  index_conversations_on_scenario_key  (scenario_key)
#
