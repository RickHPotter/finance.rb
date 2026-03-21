# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::MessageBackfillAudit do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:conversation) do
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: sender)
        record.conversation_participants.create!(user: receiver)
      end
    end
    let(:reference_transaction) { create(:cash_transaction, user: sender, user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random))) }

    before do
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
      conversation.messages.create!(
        user: sender,
        body: "hello"
      )
    end

    it "audits the full table with backfill kinds and proposed conversation roles" do
      report = described_class.new.call

      expect(report[:counts]).to include(
        "transaction_notification" => 1,
        "transaction_destroy_notification" => 1,
        "human" => 1
      )

      expect(report[:messages]).to include(
        a_hash_including(backfill_kind: "transaction_notification", proposed_conversation_role: "assistant"),
        a_hash_including(backfill_kind: "transaction_destroy_notification", proposed_conversation_role: "assistant"),
        a_hash_including(backfill_kind: "human", proposed_conversation_role: "human")
      )
    end
  end
end
