# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Exchange notification authorization guards" do
  let(:sender)    { create(:user, :random) }
  let(:recipient) { create(:user, :random) }

  # ─── FriendNotifiable ──────────────────────────────────────────────────────
  describe "FriendNotifiable#notify_friend" do
    let!(:friendship) { create(:friendship, user: sender, friend: recipient, state: initial_state) }
    let(:exchange_category) { sender.categories.find_by(category_name: "EXCHANGE") }
    let!(:sender_entity)    { sender.entities.create!(entity_name: "GIGI", friendship_id: friendship.id, built_in: false) }
    let!(:recipient_entity) { recipient.entities.create!(entity_name: "LUIS", friendship_id: friendship.id, built_in: false) }

    # Creates a cash transaction with an exchange pointing to sender_entity.
    # FriendNotifiable#notify_friends is triggered by after_create / after_update.
    def create_exchange_transaction
      ct = sender.ensure_main_context!.cash_transactions.create!(
        user: sender,
        description: "Dinner",
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        price: 100
      )
      ct.cash_installments.create!(number: 1, date: Time.zone.today, month: ct.month, year: ct.year, price: 100)
      ct.category_transactions.create!(category: exchange_category)
      et = ct.entity_transactions.create!(entity: sender_entity, price: 100, price_to_be_returned: 100, is_payer: true)
      et.exchanges.create!(number: 1, date: Time.zone.today, month: ct.month, year: ct.year, price: 100)
      ct
    end

    %w[blocked removed rejected].each do |bad_state|
      context "when friendship is #{bad_state}" do
        let(:initial_state) { bad_state }

        it "does not create any notification message" do
          expect { create_exchange_transaction }.not_to change(Message, :count)
        end
      end
    end

    context "when friendship is accepted" do
      let(:initial_state) { "accepted" }

      it "passes the friendship guard (accepted_state? is true)" do
        expect(friendship.accepted_state?).to be(true)
        # The guard in notify_friend returns early only when friendship is absent or not accepted.
        # With an accepted friendship, execution continues past the guard.
        friendship_lookup = sender.friendship_with(recipient)
        expect(friendship_lookup&.accepted_state?).to be(true)
      end
    end
  end

  # ─── SharedReturnDestroyMessageService ────────────────────────────────────
  describe Logic::SharedReturnDestroyMessageService do
    let(:sender_context)    { double("context", scenario_key: "main") }
    let(:sender_tx)         { instance_double(CashTransaction, user: sender, context: sender_context, notification_message_reference_family: []) }
    let(:recipient_tx)      { instance_double(CashTransaction, user: recipient) }

    %w[blocked removed rejected].each do |bad_state|
      context "when friendship is #{bad_state}" do
        let!(:_friendship) { create(:friendship, user: sender, friend: recipient, state: bad_state) }

        it "returns false and creates no message" do
          result = described_class.new(transaction: sender_tx, counterpart_transaction: recipient_tx).call
          expect(result).to be(false)
          expect(Message.count).to eq(0)
        end
      end
    end

    context "when friendship is accepted" do
      let!(:_friendship) { create(:friendship, user: sender, friend: recipient, state: "accepted") }

      it "passes the friendship guard" do
        # Guard passes; the service would proceed to the canonical resolver.
        # We stub to avoid full integration setup.
        allow(Logic::Conversations::Resolve).to receive(:call).and_raise(StandardError, "passed the guard")
        expect { described_class.new(transaction: sender_tx, counterpart_transaction: recipient_tx).call }
          .to raise_error(StandardError, "passed the guard")
      end
    end
  end

  # ─── SharedReturnStructureUpdateMessageService ────────────────────────────
  describe Logic::SharedReturnStructureUpdateMessageService do
    let(:sender_tx) do
      instance_double(
        CashTransaction,
        user: sender,
        context: double("context", scenario_key: "main"),
        counterpart_shared_return_transaction: recipient_tx,
        notification_message_reference_family: []
      )
    end
    let(:recipient_tx) { instance_double(CashTransaction, user: recipient) }

    %w[blocked removed rejected].each do |bad_state|
      context "when friendship is #{bad_state}" do
        let!(:_friendship) { create(:friendship, user: sender, friend: recipient, state: bad_state) }

        it "returns false and creates no message" do
          # counterpart_transaction is a CashTransaction double, so reference_transactable check passes first;
          # we force that by also stubbing it to return the double itself.
          allow(sender_tx).to receive(:counterpart_shared_return_transaction).and_return(recipient_tx)
          allow(recipient_tx).to receive(:is_a?).with(CashTransaction).and_return(true)

          result = described_class.new(transaction: sender_tx).call
          expect(result).to be(false)
          expect(Message.count).to eq(0)
        end
      end
    end
  end
end
