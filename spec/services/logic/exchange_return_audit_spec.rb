# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::ExchangeReturnAudit do
  describe "#call" do
    it "returns only exchange returns with total mismatches and surfaces stale linked source rows" do
      user = create(:user, :random)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      entity = create(:entity, user:, entity_name: "LALA")
      bank_account = create(:user_bank_account, user:)
      user_card = create(:user_card, :random, user:, card: create(:card, :random))

      matching_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Healthy shared return",
        date: Time.zone.parse("2026-05-10 12:00:00"),
        month: 5,
        year: 2026,
        price: 8_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 8_000, date: Time.zone.parse("2026-05-10 12:00:00"), month: 5, year: 2026)
        ]
      )
      matching_transaction.categories = [ exchange_return_category ]
      matching_transaction.save!

      matching_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        price: -8_000,
        user_card:
      )
      matching_entity_transaction = matching_card.entity_transactions.first
      matching_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 8_000, price_to_be_returned: 8_000, exchanges_count: 1)
      Exchange.insert({
                        entity_transaction_id: matching_entity_transaction.id,
                        cash_transaction_id: matching_transaction.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 8_000,
                        starting_price: 8_000,
                        date: Time.zone.parse("2026-05-10 12:00:00"),
                        month: 5,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      mismatched_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Broken shared return",
        date: Time.zone.parse("2026-05-15 12:00:00"),
        month: 5,
        year: 2026,
        price: 85_014,
        cash_installments: [
          build(:cash_installment, number: 1, price: 85_014, date: Time.zone.parse("2026-05-15 12:00:00"), month: 5, year: 2026)
        ]
      )
      mismatched_transaction.categories = [ exchange_return_category ]
      mismatched_transaction.save!

      healthy_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        description: "Healthy source",
        price: -84_962,
        user_card:
      )
      healthy_entity_transaction = healthy_source.entity_transactions.first
      healthy_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 84_962, price_to_be_returned: 84_962, exchanges_count: 1)
      Exchange.insert({
                        entity_transaction_id: healthy_entity_transaction.id,
                        cash_transaction_id: mismatched_transaction.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 84_962,
                        starting_price: 84_962,
                        date: Time.zone.parse("2026-05-15 12:00:00"),
                        month: 5,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      stale_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        description: "Stale source",
        price: -5_268,
        user_card:
      )
      stale_entity_transaction = stale_source.entity_transactions.first
      stale_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 5_268, price_to_be_returned: 5_268, exchanges_count: 1)
      Exchange.insert({
                        entity_transaction_id: stale_entity_transaction.id,
                        cash_transaction_id: mismatched_transaction.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 52,
                        starting_price: 52,
                        date: Time.zone.parse("2026-05-15 12:00:00"),
                        month: 5,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows.map { |row| row[:id] }).to eq([ mismatched_transaction.id ])
      expect(rows.first[:context]).to eq({
                                           id: user.main_context.id,
                                           name: user.main_context.name,
                                           scenario_key: user.main_context.scenario_key
                                         })
      expect(rows.first[:price]).to eq(85_014)
      expect(rows.first[:installments_sum]).to eq(85_014)
      expect(rows.first[:exchange_rows_sum]).to eq(85_014)
      expect(rows.first[:issues]).to contain_exactly("stale_linked_source_rows")
      expect(rows.first[:linked_source_rows]).to contain_exactly(
        hash_including(
          entity_transaction_id: stale_entity_transaction.id,
          transactable_type: "CardTransaction",
          transactable_id: stale_source.id,
          description: "Stale source",
          aggregate_total: 5_268,
          aggregate_exchange_total: 52,
          scoped_exchange_total: 52,
          delta: 5_216,
          exchanges_count: 1
        )
      )
      expect(rows.first[:source_allocation_rows]).to eq([])
    end

    it "scopes the audit to the provided context" do
      user = create(:user, :random)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      derived_context = create(:context, user:, name: "Scenario X", source_context: user.main_context)
      bank_account = create(:user_bank_account, user:)

      main_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Main mismatch",
        date: Time.zone.parse("2026-05-10 12:00:00"),
        month: 5,
        year: 2026,
        price: 10_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 9_000, date: Time.zone.parse("2026-05-10 12:00:00"), month: 5, year: 2026)
        ]
      )
      main_transaction.categories = [ exchange_return_category ]
      main_transaction.save!

      derived_transaction = create(
        :cash_transaction,
        user:,
        context: derived_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Derived mismatch",
        date: Time.zone.parse("2026-05-11 12:00:00"),
        month: 5,
        year: 2026,
        price: 20_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 18_000, date: Time.zone.parse("2026-05-11 12:00:00"), month: 5, year: 2026)
        ]
      )
      derived_transaction.categories = [ exchange_return_category ]
      derived_transaction.save!

      main_rows = described_class.new(current_user: user, current_context: user.main_context).call
      derived_rows = described_class.new(current_user: user, current_context: derived_context).call

      expect(main_rows.map { |row| row[:id] }).to eq([ main_transaction.id ])
      expect(derived_rows.map { |row| row[:id] }).to eq([ derived_transaction.id ])
    end

    it "does not flag split source transactions when entity allocations add up to the source total" do
      user = create(:user, :random)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      bank_account = create(:user_bank_account, user:)
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      entity_one = create(:entity, user:, entity_name: "ALICE")
      entity_two = create(:entity, user:, entity_name: "BOB")
      entity_three = create(:entity, user:, entity_name: "CAROL")

      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Shared return",
        date: Time.zone.parse("2026-06-10 12:00:00"),
        month: 6,
        year: 2026,
        price: 9_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 9_000, date: Time.zone.parse("2026-06-10 12:00:00"), month: 6, year: 2026)
        ]
      )
      transaction.categories = [ exchange_return_category ]
      transaction.save!

      source = create(:card_transaction, user:, context: user.main_context, price: -9_000, user_card:)
      source.entity_transactions.destroy_all
      source.entity_transactions.create!(entity: entity_one, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      source.entity_transactions.create!(entity: entity_two, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      source.entity_transactions.create!(entity: entity_three, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      now = Time.current
      source.entity_transactions.each_with_index do |entity_transaction, index|
        Exchange.insert({
                          entity_transaction_id: entity_transaction.id,
                          cash_transaction_id: transaction.id,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          bound_type: "card_bound",
                          number: index + 1,
                          price: 3_000,
                          starting_price: 3_000,
                          date: Time.zone.parse("2026-06-10 12:00:00"),
                          month: 6,
                          year: 2026,
                          exchanges_count: 1,
                          created_at: now,
                          updated_at: now
                        })
      end

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows).to eq([])
    end

    it "flags split source transactions that are missing the MOI self-share allocation" do
      user = create(:user, :random)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      bank_account = create(:user_bank_account, user:)
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      alice = create(:entity, user:, entity_name: "ALICE")
      bob = create(:entity, user:, entity_name: "BOB")

      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Pizza return",
        date: Time.zone.parse("2026-06-11 12:00:00"),
        month: 6,
        year: 2026,
        price: 6_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 6_000, date: Time.zone.parse("2026-06-11 12:00:00"), month: 6, year: 2026)
        ]
      )
      transaction.categories = [ exchange_return_category ]
      transaction.save!

      source = create(:card_transaction, user:, context: user.main_context, price: -9_000, user_card:)
      source.entity_transactions.destroy_all
      et_one = source.entity_transactions.create!(entity: alice, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      et_two = source.entity_transactions.create!(entity: bob, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      now = Time.current
      [ et_one, et_two ].each_with_index do |entity_transaction, index|
        Exchange.insert({
                          entity_transaction_id: entity_transaction.id,
                          cash_transaction_id: transaction.id,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          bound_type: "card_bound",
                          number: index + 1,
                          price: 3_000,
                          starting_price: 3_000,
                          date: Time.zone.parse("2026-06-11 12:00:00"),
                          month: 6,
                          year: 2026,
                          exchanges_count: 1,
                          created_at: now,
                          updated_at: now
                        })
      end

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows.map { |row| row[:id] }).to eq([ transaction.id ])
      expect(rows.first[:issues]).to contain_exactly("source_allocation_mismatch")
      expect(rows.first[:source_allocation_rows]).to eq([
                                                          {
                                                            transactable_type: "CardTransaction",
                                                            transactable_id: source.id,
                                                            description: source.description,
                                                            transaction_total: 9_000,
                                                            allocation_total: 6_000,
                                                            payer_total: 6_000,
                                                            missing_amount: 3_000,
                                                            has_moi_entity: false,
                                                            issue_code: "missing_moi_allocation"
                                                          }
                                                        ])
    end

    it "filters pending rows by default and can return paid rows explicitly" do
      user = create(:user, :random)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      bank_account = create(:user_bank_account, user:)

      pending_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Pending mismatch",
        paid: false,
        date: Time.zone.parse("2026-06-12 12:00:00"),
        month: 6,
        year: 2026,
        price: 5_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 4_000, date: Time.zone.parse("2026-06-12 12:00:00"), month: 6, year: 2026)
        ]
      )
      pending_transaction.categories = [ exchange_return_category ]
      pending_transaction.save!
      pending_transaction.update_column(:paid, false)

      paid_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Paid mismatch",
        paid: true,
        date: Time.zone.parse("2026-06-13 12:00:00"),
        month: 6,
        year: 2026,
        price: 7_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 6_000, date: Time.zone.parse("2026-06-13 12:00:00"), month: 6, year: 2026)
        ]
      )
      paid_transaction.categories = [ exchange_return_category ]
      paid_transaction.save!
      paid_transaction.update_column(:paid, true)

      default_rows = described_class.new(current_user: user, current_context: user.main_context).call
      paid_rows = described_class.new(current_user: user, current_context: user.main_context, status_filter: "paid").call

      expect(default_rows.map { |row| row[:id] }).to eq([ pending_transaction.id ])
      expect(paid_rows.map { |row| row[:id] }).to eq([ paid_transaction.id ])
    end
  end
end
