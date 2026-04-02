# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::StandaloneExchangeParentReferenceRunner do
  describe "#call" do
    let(:sender) { create(:user, first_name: "Rikki", email: "rikki@example.com") }
    let(:receiver) { create(:user, first_name: "Gigi", email: "gigi@example.com") }

    def sender_entity_for(receiver_user)
      sender.entities.find_or_create_by!(entity_name: receiver_user.first_name.upcase) do |entity_record|
        entity_record.entity_user = receiver_user
      end
    end

    def sender_bank_account
      @sender_bank_account ||= create(:user_bank_account, user: sender, bank: create(:bank, :random))
    end

    def create_exchange_source(sender_entity)
      create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        cash_transaction_type: "Exchange",
        description: "Source exchange",
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        price: -1_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -1_000, price_to_be_returned: -1_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -1_000, paid: false } ]
      )
    end

    def create_standalone_exchange_return(sender_entity)
      create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        cash_transaction_type: "Exchange",
        description: "Standalone return",
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        price: -1_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false } ]
      )
    end

    def create_missing_reference_case
      sender_entity = sender_entity_for(receiver)
      source_transaction = create_exchange_source(sender_entity)
      exchange_return = create_standalone_exchange_return(sender_entity)

      create(
        :exchange,
        entity_transaction: source_transaction.entity_transactions.find_by(entity: sender_entity),
        cash_transaction: exchange_return,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -1_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )

      exchange_return.update_columns(reference_transactable_type: nil, reference_transactable_id: nil)

      [ exchange_return, source_transaction ]
    end

    it "reports supported updates during dry run" do
      exchange_return, source_transaction = create_missing_reference_case

      result = described_class.new(ids: [ exchange_return.id ], dry_run: true).call

      expect(result[:processed_count]).to eq(1)
      expect(result[:updated_count]).to eq(1)
      expect(exchange_return.reload.reference_transactable).to be_nil
      expect(result[:updates]).to include(
        a_hash_including(
          exchange_return_transaction_id: exchange_return.id,
          desired_reference: a_hash_including(id: source_transaction.id, type: "CashTransaction")
        )
      )
    end

    it "fills the missing parent reference for supported rows" do
      exchange_return, source_transaction = create_missing_reference_case

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:processed_count]).to eq(1)
      expect(result[:updated_count]).to eq(1)
      expect(exchange_return.reload.reference_transactable).to eq(source_transaction)
    end

    it "ignores rows that already gained a reference before apply" do
      exchange_return, source_transaction = create_missing_reference_case
      exchange_return.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: source_transaction.id)

      result = described_class.new(ids: [ exchange_return.id ], dry_run: false).call

      expect(result[:processed_count]).to eq(0)
      expect(result[:updated_count]).to eq(0)
      expect(result[:skipped]).to be_empty
    end
  end
end
