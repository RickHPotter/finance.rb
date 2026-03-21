# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  describe "[ business logic ]" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:conversation) do
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: sender)
        record.conversation_participants.create!(user: receiver)
      end
    end
    let(:reference_transaction) { create(:cash_transaction, user: sender, user_bank_account: create(:user_bank_account, user: sender, bank: create(:bank, :random))) }

    it "classifies header-bearing messages as transaction notifications" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "Notification",
        headers: { id: reference_transaction.id, type: "CashTransaction" }.to_json
      )

      expect(message.transaction_notification_message?).to be(true)
      expect(message.backfill_kind).to eq("transaction_notification")
    end

    it "classifies headerless messages with reference transactable as destroy notifications" do
      message = described_class.create!(
        conversation:,
        user: sender,
        reference_transactable: reference_transaction,
        body: "Destroyed"
      )

      expect(message.transaction_destroy_notification_message?).to be(true)
      expect(message.backfill_kind).to eq("transaction_destroy_notification")
    end

    it "classifies headerless messages without reference transactable as human chat" do
      message = described_class.create!(
        conversation:,
        user: sender,
        body: "hello"
      )

      expect(message.human_message?).to be(true)
      expect(message.backfill_kind).to eq("human")
    end
  end
end

# == Schema Information
#
# Table name: messages
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  body                        :text
#  headers                     :text
#  read_at                     :datetime
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  conversation_id             :bigint           not null, indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  superseded_by_id            :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_messages_on_conversation_id         (conversation_id)
#  index_messages_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_messages_on_superseded_by_id        (superseded_by_id)
#  index_messages_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (superseded_by_id => messages.id)
#  fk_rails_...  (user_id => users.id)
#
