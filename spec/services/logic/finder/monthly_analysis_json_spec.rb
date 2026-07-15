# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Finder::MonthlyAnalysisJson do
  subject(:payload) { described_class.new(user:, context:, month: "2026-07").call }

  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }

  describe "ordinary movement" do
    it "reconciles selected-month cash and card installments across deterministic bundles" do
      transport = create(:category, user:, category_name: "TRANSPORT", colour: "#dc2626")
      food = create(:category, user:, category_name: "FOOD", colour: "#16a34a")
      bruno = create(:entity, user:, entity_name: "BRUNO")
      ana = create(:entity, user:, entity_name: "ANA")

      create_cash_transaction(price: 12_345, categories: [ food ], entities: [ ana ], parent_month: 6)
      create_card_transaction(price: -4_567, categories: [ transport, food ], entities: [ bruno, ana ], parent_month: 5)

      expect(payload[:ordinary]).to include(net: 77.78)
      expect(payload.dig(:ordinary, :income)).to include(total: 123.45)
      expect(payload.dig(:ordinary, :outcome)).to include(total: 45.67)
      expect(payload.dig(:ordinary, :income, :categories)).to contain_exactly(
        include(key: "categories:#{food.id}", label: "FOOD", amount: 123.45, color: "#16a34a")
      )
      expect(payload.dig(:ordinary, :outcome, :categories)).to contain_exactly(
        include(key: "categories:#{food.id}+#{transport.id}", label: "FOOD + TRANSPORT", amount: 45.67, color: "#78716c")
      )
      expect(payload.dig(:ordinary, :outcome, :entities)).to contain_exactly(
        include(key: "entities:#{ana.id}+#{bruno.id}", label: "ANA + BRUNO", amount: 45.67)
      )
    end

    it "uses localized unassigned bundles without losing the installment amount" do
      create_cash_transaction(price: -2_501, categories: [], entities: [])

      expect(payload.dig(:ordinary, :outcome, :categories)).to contain_exactly(
        include(key: "category:unassigned", label: I18n.t("balances.monthly_analysis.unassigned"), amount: 25.01)
      )
      expect(payload.dig(:ordinary, :outcome, :entities)).to contain_exactly(
        include(key: "entity:unassigned", label: I18n.t("balances.monthly_analysis.unassigned"), amount: 25.01)
      )
    end

    it "excludes other months, contexts, generated projections, transfers, and piggy-bank rows" do
      create_cash_transaction(price: 1_000, categories: [], entities: [], installment_month: 8)
      create_cash_transaction(price: 2_000, categories: [], entities: [], context: create(:context, user:))
      create_cash_transaction(price: 3_000, categories: [], entities: [], cash_transaction_type: "CardInstallment")
      create_cash_transaction(price: 4_000, categories: [], entities: [], cash_transaction_type: "Investment")
      transfer = create_cash_transaction(price: 5_000, categories: [], entities: [])
      piggy_bank = create_cash_transaction(price: -6_000, categories: [], entities: [])
      create(:category_transaction, transactable: transfer, category: user.built_in_category("EXCHANGE"))
      create(:category_transaction, transactable: piggy_bank, category: user.built_in_category("PIGGY BANK"))

      expect(payload.dig(:ordinary, :income, :total)).to eq(0.0)
      expect(payload.dig(:ordinary, :outcome, :total)).to eq(0.0)
    end
  end

  describe "month validation" do
    it "rejects missing, malformed, and impossible months" do
      [ nil, "", "2026-7", "2026-07-01", "2026-13" ].each do |month|
        expect { described_class.new(user:, context:, month:) }
          .to raise_error(described_class::InvalidMonthError, I18n.t("balances.monthly_analysis.invalid_month"))
      end
    end
  end

  describe "transfers" do
    it "aggregates context-scoped monetary exchanges by their own month and direction" do
      ana = create(:entity, user:, entity_name: "ANA")
      bruno = create(:entity, user:, entity_name: "BRUNO")
      sent_source = create_cash_transaction(price: -5_000, categories: [], entities: [], installment_month: 8)
      received_source = create_card_transaction(price: 1_250, categories: [], entities: [], installment_month: 8)
      sent_allocation = attach_transfer(sent_source, entity: ana, category_name: "EXCHANGE", is_payer: true)
      received_allocation = attach_transfer(received_source, entity: bruno, category_name: "EXCHANGE RETURN", is_payer: false)

      create_exchange(sent_allocation, price: 3_000, number: 1)
      create_exchange(sent_allocation, price: 2_000, number: 2)
      create_exchange(sent_allocation, price: 9_000, number: 3, exchange_type: :non_monetary)
      create_exchange(sent_allocation, price: 7_000, number: 4, month: 8)
      create_exchange(received_allocation, price: 1_250, number: 1)

      foreign_context = create(:context, user:)
      foreign_source = create_cash_transaction(price: -4_000, categories: [], entities: [], context: foreign_context, installment_month: 8)
      foreign_allocation = attach_transfer(foreign_source, entity: ana, category_name: "EXCHANGE", is_payer: true)
      create_exchange(foreign_allocation, price: 4_000, number: 1)

      expect(payload[:transfers]).to include(total_sent: 50.0, total_received: 12.5)
      expect(payload.dig(:transfers, :items)).to contain_exactly(
        { entity_id: ana.id, entity_label: "ANA", direction: "sent", amount: 50.0 },
        { entity_id: bruno.id, entity_label: "BRUNO", direction: "received", amount: 12.5 }
      )
      expect(payload.dig(:ordinary, :income, :total)).to eq(0.0)
      expect(payload.dig(:ordinary, :outcome, :total)).to eq(0.0)
    end

    it "reports failed returns from starting price without treating them as ordinary or monetary transfers" do
      ana = create(:entity, user:, entity_name: "ANA")
      failed_return = create_cash_transaction(price: 1, categories: [], entities: [ ana ])
      failed_return.update_columns(price: 0)
      failed_return.cash_installments.first.update_columns(price: 0, starting_price: 7_500)
      create(:category_transaction, transactable: failed_return, category: user.built_in_category("FAILED LEND/BORROW RETURN"))

      expect(payload.dig(:transfers, :failed)).to contain_exactly(
        {
          key: "entities:#{ana.id}",
          entity_label: "ANA",
          amount: 75.0,
          state: "failed",
          amount_source: "starting_price"
        }
      )
      expect(payload[:transfers]).to include(total_sent: 0.0, total_received: 0.0, items: [])
      expect(payload.dig(:ordinary, :income, :total)).to eq(0.0)
      expect(payload.dig(:ordinary, :outcome, :total)).to eq(0.0)
    end
  end

  def create_cash_transaction(price:, categories:, entities:, **options)
    transaction_context = options.fetch(:context, context)
    installment_month = options.fetch(:installment_month, 7)
    parent_month = options.fetch(:parent_month, installment_month)

    create(
      :cash_transaction,
      user:,
      context: transaction_context,
      user_bank_account: account,
      cash_transaction_type: options[:cash_transaction_type],
      date: Date.new(2026, parent_month, 10),
      month: parent_month,
      year: 2026,
      price:,
      cash_installments: [ build_installment(:cash_installment, price:, month: installment_month) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) },
      entity_transactions: entities.map { |entity| EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) }
    )
  end

  def create_card_transaction(price:, categories:, entities:, installment_month: 7, parent_month: installment_month)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: Date.new(2026, parent_month, 10),
      month: parent_month,
      year: 2026,
      price:,
      card_installments: [ build_installment(:card_installment, price:, month: installment_month) ],
      category_transactions: categories.map { |category| CategoryTransaction.new(category:) },
      entity_transactions: entities.map { |entity| EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) }
    )
  end

  def build_installment(factory, price:, month:)
    build(factory, number: 1, price:, date: Date.new(2026, month, 10), month:, year: 2026, paid: false)
  end

  def attach_transfer(transaction, entity:, category_name:, is_payer:)
    create(:category_transaction, transactable: transaction, category: user.built_in_category(category_name))
    EntityTransaction.create!(
      transactable: transaction,
      entity:,
      price: is_payer ? transaction.price.abs : 0,
      price_to_be_returned: is_payer ? transaction.price.abs : 0,
      is_payer:
    )
  end

  def create_exchange(entity_transaction, price:, number:, month: 7, exchange_type: :monetary)
    Exchange.create!(
      entity_transaction:,
      exchange_type:,
      bound_type: :standalone,
      price:,
      number:,
      date: Date.new(2026, month, 10),
      month:,
      year: 2026
    )
  end
end
