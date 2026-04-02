# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::StandaloneExchangeParentReferenceAudit do
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

    def create_standalone_exchange_return(parent:, entity:)
      exchange_return = create(
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
        entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false } ]
      )

      create(
        :exchange,
        entity_transaction: parent.entity_transactions.find_by(entity:),
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

      exchange_return
    end

    it "returns a supported candidate when a standalone exchange return has one cash parent source" do
      sender_entity = sender_entity_for(receiver)
      source_transaction = create(
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
      exchange_return = create_standalone_exchange_return(parent: source_transaction, entity: sender_entity)

      result = described_class.new.call
      candidate = result[:candidates].find { |entry| entry[:exchange_return_transaction_id] == exchange_return.id }

      expect(candidate).to include(
        exchange_return_transaction_id: exchange_return.id,
        supported: true,
        desired_reference: a_hash_including(id: source_transaction.id, type: "CashTransaction")
      )
    end

    it "returns a supported candidate when a standalone exchange return has one card parent source" do
      sender_entity = sender_entity_for(receiver)
      source_transaction = create(
        :card_transaction,
        user: sender,
        context: sender.main_context,
        user_card: create(:user_card, user: sender),
        description: "Card source exchange",
        date: Date.new(2026, 3, 18),
        month: 4,
        year: 2026,
        price: -1_000,
        category_transactions: [ build(:category_transaction, category: sender.built_in_category("EXCHANGE"), transactable: nil) ],
        entity_transactions: [ build(:entity_transaction, entity: sender_entity, is_payer: true, transactable: nil, price: -1_000, price_to_be_returned: -1_000) ],
        card_installments: [ build(:card_installment, number: 1, price: -1_000, date: Date.new(2026, 3, 18), month: 4, year: 2026) ]
      )
      exchange_return = create_standalone_exchange_return(parent: source_transaction, entity: sender_entity)

      result = described_class.new.call
      candidate = result[:candidates].find { |entry| entry[:exchange_return_transaction_id] == exchange_return.id }

      expect(candidate).to include(
        exchange_return_transaction_id: exchange_return.id,
        supported: true,
        desired_reference: a_hash_including(id: source_transaction.id, type: "CardTransaction")
      )
    end

    it "marks rows with multiple standalone parent candidates as unsupported" do
      sender_entity = sender_entity_for(receiver)
      first_source = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        cash_transaction_type: "Exchange",
        description: "First source exchange",
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        price: -1_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -1_000, price_to_be_returned: -1_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -1_000, paid: false } ]
      )
      second_source = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        cash_transaction_type: "Exchange",
        description: "Second source exchange",
        date: Date.new(2026, 3, 19),
        month: 3,
        year: 2026,
        price: -1_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -1_000, price_to_be_returned: -1_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 19), month: 3, year: 2026, price: -1_000, paid: false } ]
      )
      exchange_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        cash_transaction_type: "Exchange",
        description: "Ambiguous return",
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        price: -2_000,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -2_000, paid: false } ]
      )

      [ first_source, second_source ].each_with_index do |source_transaction, index|
        create(
          :exchange,
          entity_transaction: source_transaction.entity_transactions.find_by(entity: sender_entity),
          cash_transaction: exchange_return,
          bound_type: :standalone,
          exchange_type: :monetary,
          number: index + 1,
          price: -1_000,
          date: Date.new(2026, 3, 20 + index),
          month: 3,
          year: 2026
        )
      end

      exchange_return.update_columns(reference_transactable_type: nil, reference_transactable_id: nil)

      result = described_class.new.call
      candidate = result[:candidates].find { |entry| entry[:exchange_return_transaction_id] == exchange_return.id }

      expect(candidate).to include(
        exchange_return_transaction_id: exchange_return.id,
        supported: false,
        unsupported_reason: "multiple_parent_candidates"
      )
    end
  end
end
