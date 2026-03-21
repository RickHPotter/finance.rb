# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::MessageBackfillRunner do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:conversation) { Conversation.create_with_participants!(sender, receiver) }
    let(:reference_transaction) do
      create(:cash_transaction, user: sender, user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random)))
    end

    before do
      conversation.messages.create!(user: sender, body: "hello")
      conversation.messages.create!(
        user: sender,
        reference_transactable: reference_transaction,
        body: "Notification",
        headers: { id: reference_transaction.id, type: "CashTransaction" }.to_json
      )
      conversation.messages.create!(
        user: sender,
        reference_transactable: reference_transaction,
        body: "Destroyed"
      )
    end

    it "moves human and assistant messages into distinct conversation kinds" do
      result = described_class.new(dry_run: false).call

      expect(result[:moved_messages_count]).to eq(2)
      expect(result[:rewritten_messages_count]).to eq(2)

      human_message = Message.find_by(body: "hello")
      notification_message = Message.where(reference_transactable: reference_transaction)
                                    .where("headers LIKE ?", "%message_notification_v2%")
                                    .find_by(body: "notification:create")
      destroy_message = Message.where(reference_transactable: reference_transaction).find_by(body: "notification:destroy")

      expect(human_message.conversation.kind).to eq("human")
      expect(notification_message.conversation.kind).to eq("assistant")
      expect(JSON.parse(notification_message.headers)).to include("version" => "message_notification_v2")
      expect(JSON.parse(notification_message.headers).dig("event", "action")).to eq("create")
      expect(destroy_message.conversation.kind).to eq("assistant")
      expect(destroy_message.conversation).to eq(notification_message.conversation)
      expect(JSON.parse(destroy_message.headers).dig("event", "action")).to eq("destroy")
    end
  end
end
