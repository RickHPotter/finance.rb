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

      human_message = Message.find_by(body: "hello")
      notification_message = Message.find_by(body: "Notification")
      destroy_message = Message.find_by(body: "Destroyed")

      expect(human_message.conversation.kind).to eq("human")
      expect(notification_message.conversation.kind).to eq("assistant")
      expect(notification_message.conversation.assistant_owner).to eq(receiver)
      expect(destroy_message.conversation.kind).to eq("assistant")
      expect(destroy_message.conversation.assistant_owner).to eq(receiver)
    end
  end
end
