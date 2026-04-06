# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeAuditConnections do
  describe "#call" do
    it "groups visible rows by connected user, defaults to the most urgent connection, and exposes entity mappings" do
      current_user = create(:user, :random)
      connected_user = create(:user, :random, first_name: "Rikki")
      another_user = create(:user, :random, first_name: "Pat")
      stranger = create(:user, :random, first_name: "Stranger")

      current_user.entities.create!(entity_name: "LUIS", entity_user: connected_user)
      connected_user.entities.create!(entity_name: "GIGI", entity_user: current_user)
      current_user.entities.create!(entity_name: "PATRICIA", entity_user: another_user)
      another_user.entities.create!(entity_name: "GISAX", entity_user: current_user)

      rows = [
        {
          status: "pending",
          message: { id: 1, created_at: Time.zone.parse("2026-04-06 10:00:00") },
          sender: { id: current_user.id, first_name: current_user.first_name, email: current_user.email },
          receiver: { id: connected_user.id, first_name: connected_user.first_name, email: connected_user.email }
        },
        {
          status: "done",
          message: { id: 2, created_at: Time.zone.parse("2026-04-05 10:00:00") },
          sender: { id: current_user.id, first_name: current_user.first_name, email: current_user.email },
          receiver: { id: another_user.id, first_name: another_user.first_name, email: another_user.email }
        },
        {
          status: "pending",
          message: { id: 3, created_at: Time.zone.parse("2026-04-04 10:00:00") },
          sender: { id: stranger.id, first_name: stranger.first_name, email: stranger.email },
          receiver: { id: another_user.id, first_name: another_user.first_name, email: another_user.email }
        }
      ]

      result = described_class.new(rows:, current_user:).call

      expect(result[:connections].map { |connection| connection[:connected_user_id] }).to eq([ connected_user.id, another_user.id ])
      expect(result[:selected_connected_user_id]).to eq(connected_user.id)
      expect(result[:rows].map { |row| row.dig(:message, :id) }).to eq([ 1 ])
      expect(result[:selected_connection][:your_entity_names]).to eq([ "LUIS" ])
      expect(result[:selected_connection][:their_entity_names]).to eq([ "GIGI" ])
    end

    it "honors an explicit connected-user selection" do
      current_user = create(:user, :random)
      connected_user = create(:user, :random)
      another_user = create(:user, :random)

      rows = [
        {
          status: "pending",
          message: { id: 1, created_at: Time.zone.parse("2026-04-06 10:00:00") },
          sender: { id: current_user.id, first_name: current_user.first_name, email: current_user.email },
          receiver: { id: connected_user.id, first_name: connected_user.first_name, email: connected_user.email }
        },
        {
          status: "done",
          message: { id: 2, created_at: Time.zone.parse("2026-04-05 10:00:00") },
          sender: { id: current_user.id, first_name: current_user.first_name, email: current_user.email },
          receiver: { id: another_user.id, first_name: another_user.first_name, email: another_user.email }
        }
      ]

      result = described_class.new(rows:, current_user:, selected_connected_user_id: another_user.id).call

      expect(result[:selected_connected_user_id]).to eq(another_user.id)
      expect(result[:rows].map { |row| row.dig(:message, :id) }).to eq([ 2 ])
    end
  end
end
