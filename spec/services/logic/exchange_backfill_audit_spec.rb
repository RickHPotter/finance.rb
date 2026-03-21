# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeBackfillAudit do
  describe "#call" do
    let(:rikki) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:gigi) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:rikki_bank_account) { create(:user_bank_account, user: rikki, bank: create(:bank, :random)) }
    let(:gigi_bank_account) { create(:user_bank_account, user: gigi, bank: create(:bank, :random)) }
    let(:rikki_entity_for_gigi) { create(:entity, user: rikki, entity_name: "Gigi", entity_user: gigi) }
    let(:gigi_entity_for_rikki) { create(:entity, user: gigi, entity_name: "Rikki", entity_user: rikki) }
    let(:service) { described_class.new(user_a: rikki, user_b: gigi) }

    let!(:source_transaction) do
      create(
        :cash_transaction,
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL",
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        price: 5_000
      ).tap do |transaction|
        transaction.categories << rikki.categories.find_by(category_name: "EXCHANGE")
      end
    end

    let!(:source_entity_transaction) do
      create(
        :entity_transaction,
        transactable: source_transaction,
        entity: rikki_entity_for_gigi,
        is_payer: true,
        price: -5_000,
        price_to_be_returned: -5_000
      )
    end

    let!(:source_exchange) do
      create(
        :exchange,
        entity_transaction: source_entity_transaction,
        price: -5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026
      )
    end

    let!(:receiver_reference_transaction) do
      create(
        :cash_transaction,
        user: gigi,
        user_bank_account: gigi_bank_account,
        reference_transactable: source_transaction,
        description: "WATER BILL",
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        price: -5_000
      ).tap do |transaction|
        transaction.categories << gigi.categories.find_by(category_name: "EXCHANGE")
        create(
          :entity_transaction,
          transactable: transaction,
          entity: gigi_entity_for_rikki,
          is_payer: true,
          price: -5_000,
          price_to_be_returned: -5_000
        )
      end
    end

    let!(:conversation) do
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end
    end
    let!(:message) do
      conversation.messages.create!(
        user: rikki,
        reference_transactable: source_transaction,
        body: "Audit me",
        headers: {
          id: source_transaction.id,
          type: "CashTransaction",
          description: "WATER BILL",
          price: -5_000,
          date: "2026-03-17",
          month: 3,
          year: 2026,
          category_ids: gigi.categories.find_by(category_name: "EXCHANGE").id,
          entity_ids: gigi_entity_for_rikki.id,
          cash_installments_attributes: [
            { number: 1, price: -5_000, date: "2026-03-17", month: 3, year: 2026 }
          ],
          entity_transactions_attributes: [
            {
              price: -5_000,
              price_to_be_returned: -5_000,
              entity_id: gigi_entity_for_rikki.id,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, price: -5_000, date: "2026-03-17", month: 3, year: 2026 }
              ]
            }
          ]
        }.to_json
      )
    end

    it "reports only sender-side root exchange transactions between the two users" do
      report = service.call

      expect(report[:cases].size).to eq(1)
      expect(report[:cases].first[:source_transaction][:id]).to eq(source_transaction.id)
      expect(report[:cases].first[:receiver_reference_transaction][:id]).to eq(receiver_reference_transaction.id)
      expect(report[:cases].first[:latest_active_message][:id]).to eq(message.id)
    end

    it "computes a structural snapshot diff against the receiver-side transaction" do
      receiver_reference_transaction.update!(description: "WATER BILL - HALF")

      report = service.call

      expect(report[:cases].first[:snapshot_diff]).to include(
        description: {
          snapshot: "WATER BILL",
          current: "WATER BILL - HALF"
        }
      )
    end
  end
end
