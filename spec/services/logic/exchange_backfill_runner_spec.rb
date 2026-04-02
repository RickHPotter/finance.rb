# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeBackfillRunner do
  describe "#call" do
    let(:rikki) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:gigi) { create(:user, first_name: "Gigi", email: "gigi@example.com") }
    let(:rikki_bank_account) { create(:user_bank_account, user: rikki, bank: create(:bank, :random)) }
    let(:gigi_bank_account) { create(:user_bank_account, user: gigi, bank: create(:bank, :random)) }
    let(:rikki_entity_for_gigi) { create(:entity, user: rikki, entity_name: "Gigi", entity_user: gigi) }
    let(:gigi_entity_for_rikki) { create(:entity, user: gigi, entity_name: "Rikki", entity_user: rikki) }

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
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )
    end

    let!(:receiver_reference_transaction) do
      create(
        :cash_transaction,
        user: gigi,
        context: gigi.main_context,
        user_bank_account: gigi_bank_account,
        reference_transactable: source_transaction,
        description: "WATER BILL - HALF",
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        price: 2_500
      ).tap do |transaction|
        transaction.categories << gigi.categories.find_by(category_name: "BORROW RETURN")
        create(
          :entity_transaction,
          transactable: transaction,
          entity: gigi_entity_for_rikki,
          is_payer: false,
          price: 0,
          price_to_be_returned: 0
        )

        transaction.cash_installments.first.update!(
          price: 2_500,
          date: Date.new(2026, 3, 20),
          month: 3,
          year: 2026
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
            { number: 1, price: -5_000, date: "2026-03-20", month: 3, year: 2026 }
          ],
          entity_transactions_attributes: [
            {
              is_payer: true,
              price: -5_000,
              price_to_be_returned: -5_000,
              entity_id: gigi_entity_for_rikki.id,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, price: -5_000, date: "2026-03-20", month: 3, year: 2026 }
              ]
            }
          ]
        }.to_json
      )
    end
    let!(:descendant_message) do
      conversation.messages.create!(
        user: rikki,
        reference_transactable: receiver_reference_transaction,
        body: "Audit descendant",
        headers: {
          id: source_transaction.id,
          type: "CashTransaction",
          description: "WATER BILL",
          price: -5_000,
          date: "2026-03-17",
          month: 3,
          year: 2026
        }.to_json
      )
    end

    let!(:derived_context) { create(:context, user: rikki, name: "Runner Derived", source_context: rikki.main_context) }
    let!(:derived_source_transaction) do
      create(
        :cash_transaction,
        user: rikki,
        context: derived_context,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL - DERIVED",
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        price: 9_999
      ).tap do |transaction|
        transaction.categories << rikki.categories.find_by(category_name: "EXCHANGE")
      end
    end
    let!(:derived_source_entity_transaction) do
      create(
        :entity_transaction,
        transactable: derived_source_transaction,
        entity: rikki_entity_for_gigi,
        is_payer: true,
        price: -9_999,
        price_to_be_returned: -9_999
      )
    end
    let!(:derived_source_exchange) do
      create(
        :exchange,
        entity_transaction: derived_source_entity_transaction,
        price: -9_999,
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026
      )
    end

    it "rewrites headers from the current receiver-side transaction when reimbursement is selected" do
      result = described_class.new(
        user_a: rikki,
        user_b: gigi,
        mapping: { source_transaction.id.to_s => "reimbursement" },
        dry_run: false
      ).call

      message.reload
      descendant_message.reload
      headers = JSON.parse(message.headers)
      descendant_headers = JSON.parse(descendant_message.headers)

      expect(result[:updated_messages_count]).to eq(1)
      expect(result[:updates].first[:message_ids]).to match_array([ message.id, descendant_message.id ])
      expect(headers).to include(
        "id" => source_transaction.id,
        "type" => "CashTransaction",
        "description" => "WATER BILL - HALF",
        "price" => 2500,
        "category_ids" => gigi.categories.find_by(category_name: "BORROW RETURN").id
      )
      expect(descendant_headers.fetch("description")).to eq("WATER BILL - HALF")
      expect(headers.fetch("cash_installments_attributes")).to contain_exactly(
        a_hash_including(
          "price" => 2500,
          "date" => "2026-03-20T00:00:00.000-03:00"
        )
      )
    end

    it "ignores derived-context source transactions when applying mappings" do
      result = described_class.new(
        user_a: rikki,
        user_b: gigi,
        mapping: { derived_source_transaction.id.to_s => "reimbursement" },
        dry_run: false
      ).call

      expect(result[:updated_messages_count]).to eq(0)
      expect(result[:skipped]).to include(
        a_hash_including(
          source_transaction_id: derived_source_transaction.id,
          reason: "source_transaction_not_found"
        )
      )
    end

    it "reports unresolved reimbursement cases without mutating headers" do
      receiver_reference_transaction.destroy!

      result = described_class.new(
        user_a: rikki,
        user_b: gigi,
        mapping: { source_transaction.id.to_s => "reimbursement" },
        dry_run: false
      ).call

      message.reload

      expect(result[:updated_messages_count]).to eq(0)
      expect(result[:skipped]).to include(
        a_hash_including(
          source_transaction_id: source_transaction.id,
          reason: "target_headers_not_resolvable",
          intent: "reimbursement"
        )
      )
      expect(JSON.parse(message.headers).fetch("description")).to eq("WATER BILL")
    end
  end
end
