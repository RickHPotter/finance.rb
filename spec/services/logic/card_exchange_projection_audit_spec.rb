# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CardExchangeProjectionAudit do
  describe "#call" do
    it "flags card transactions whose payer exchanges no longer match the installment projection buckets" do
      user = create(:user, :random)
      entity = create(:entity, user:, entity_name: "LALA")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      bank_account = create(:user_bank_account, user:)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      april_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 04/2026 ] LALA - PP",
        date: Time.zone.parse("2026-04-10 12:00:00"),
        month: 4,
        year: 2026,
        price: 37_144,
        cash_installments: [
          build(:cash_installment, number: 1, price: 262, date: Time.zone.parse("2026-04-07 13:30:00"), month: 4, year: 2026),
          build(:cash_installment, number: 2, price: 36_882, date: Time.zone.parse("2026-04-08 20:19:00"), month: 4, year: 2026)
        ]
      )
      april_return.categories = [ exchange_return_category ]
      april_return.save!

      healthy_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Healthy",
        price: -6_000,
        date: Time.zone.parse("2026-03-14 18:02:00"),
        month: 4,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -3_000, date: Time.zone.parse("2026-03-14 18:02:00"), month: 4, year: 2026),
          build(:card_installment, number: 2, price: -3_000, date: Time.zone.parse("2026-04-14 18:02:00"), month: 5, year: 2026)
        ]
      )
      healthy_entity_transaction = healthy_card.entity_transactions.first
      healthy_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 6_000, price_to_be_returned: 6_000, exchanges_count: 2)
      now = Time.current
      Exchange.insert({
                        entity_transaction_id: healthy_entity_transaction.id,
                        cash_transaction_id: april_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 3_000,
                        starting_price: 3_000,
                        date: Time.zone.parse("2026-04-07 13:30:00"),
                        month: 4,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })
      may_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 05/2026 ] LALA - PP",
        date: Time.zone.parse("2026-05-10 12:00:00"),
        month: 5,
        year: 2026,
        price: 3_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 3_000, date: Time.zone.parse("2026-05-10 12:00:00"), month: 5, year: 2026)
        ]
      )
      may_return.categories = [ exchange_return_category ]
      may_return.save!
      Exchange.insert({
                        entity_transaction_id: healthy_entity_transaction.id,
                        cash_transaction_id: may_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 2,
                        price: 3_000,
                        starting_price: 3_000,
                        date: Time.zone.parse("2026-05-10 12:00:00"),
                        month: 5,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })

      broken_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "ATACADAO",
        price: -13_434,
        date: Time.zone.parse("2026-03-14 18:02:00"),
        month: 4,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -6_717, date: Time.zone.parse("2026-03-14 18:02:00"), month: 4, year: 2026),
          build(:card_installment, number: 2, price: -6_717, date: Time.zone.parse("2026-04-14 18:02:00"), month: 5, year: 2026)
        ]
      )
      broken_entity_transaction = broken_card.entity_transactions.first
      broken_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 37_144, price_to_be_returned: 37_144, exchanges_count: 2)
      Exchange.insert({
                        entity_transaction_id: broken_entity_transaction.id,
                        cash_transaction_id: april_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 262,
                        starting_price: 262,
                        date: Time.zone.parse("2026-04-07 13:30:00"),
                        month: 4,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })
      Exchange.insert({
                        entity_transaction_id: broken_entity_transaction.id,
                        cash_transaction_id: april_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 2,
                        price: 36_882,
                        starting_price: 36_882,
                        date: Time.zone.parse("2026-04-08 20:19:00"),
                        month: 4,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows.map { |row| row[:id] }).to eq([ broken_card.id ])
      expect(rows.first[:payer_entity_transaction_ids]).to eq([ broken_entity_transaction.id ])
      expect(rows.first[:issues]).to contain_exactly("source_allocation_mismatch")
      expect(rows.first[:warnings]).to contain_exactly("projection_shape_mismatch", "duplicate_projection_buckets")
      expect(rows.first[:expected_rows].map { |entry| [ entry[:month], entry[:year], entry[:price] ] }).to eq([
                                                                                                                [ 4, 2026, 6_717 ],
                                                                                                                [ 5, 2026, 6_717 ]
                                                                                                              ])
      expect(rows.first[:actual_rows].map { |entry| [ entry[:cash_transaction_id], entry[:month], entry[:year], entry[:price] ] }).to eq([
                                                                                                                                           [ april_return.id, 4,
                                                                                                                                             2026, 262 ],
                                                                                                                                           [ april_return.id, 4, 2026,
                                                                                                                                             36_882 ]
                                                                                                                                         ])
      expect(rows.first[:allocation_issue]).to eq({
                                                    transactable_type: "CardTransaction",
                                                    transactable_id: broken_card.id,
                                                    description: "ATACADAO",
                                                    transaction_total: 13_434,
                                                    allocation_total: 37_144,
                                                    payer_total: 37_144,
                                                    missing_amount: -23_710,
                                                    has_moi_entity: false,
                                                    issue_code: "entity_allocation_mismatch"
                                                  })
    end

    it "scopes the audit to the provided context" do
      user = create(:user, :random)
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      derived_context = create(:context, user:, name: "Scenario Y", source_context: user.main_context)

      main_card = create(:card_transaction, user:, context: user.main_context, user_card:, description: "Main card")
      main_card.entity_transactions.first.update_columns(is_payer: true, price: 1_000, price_to_be_returned: 1_000)
      create(:exchange, entity_transaction: main_card.entity_transactions.first, exchange_type: :monetary, price: 500, month: 4, year: 2026)

      derived_card = create(:card_transaction, user:, context: derived_context, user_card:, description: "Derived card")
      derived_card.entity_transactions.first.update_columns(is_payer: true, price: 1_000, price_to_be_returned: 1_000)
      create(:exchange, entity_transaction: derived_card.entity_transactions.first, exchange_type: :monetary, price: 500, month: 4, year: 2026)

      main_rows = described_class.new(current_user: user, current_context: user.main_context).call
      derived_rows = described_class.new(current_user: user, current_context: derived_context).call

      expect(main_rows.map { |row| row[:id] }).to eq([ main_card.id ])
      expect(derived_rows.map { |row| row[:id] }).to eq([ derived_card.id ])
    end

    it "does not flag shape-only differences when expected and actual totals still match" do
      user = create(:user, :random)
      entity = create(:entity, user:, entity_name: "LALA")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      bank_account = create(:user_bank_account, user:)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      april_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 04/2026 ] LALA - PP",
        date: Time.zone.parse("2026-04-10 12:00:00"),
        month: 4,
        year: 2026,
        price: 6_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 6_000, date: Time.zone.parse("2026-04-10 12:00:00"), month: 4, year: 2026)
        ]
      )
      april_return.categories = [ exchange_return_category ]
      april_return.save!

      equal_total_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Equal total shape diff",
        price: -6_000,
        date: Time.zone.parse("2026-03-14 18:02:00"),
        month: 4,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -3_000, date: Time.zone.parse("2026-03-14 18:02:00"), month: 4, year: 2026),
          build(:card_installment, number: 2, price: -3_000, date: Time.zone.parse("2026-04-14 18:02:00"), month: 5, year: 2026)
        ]
      )
      equal_total_entity_transaction = equal_total_card.entity_transactions.first
      equal_total_entity_transaction.update_columns(entity_id: entity.id, is_payer: true, price: 6_000, price_to_be_returned: 6_000, exchanges_count: 2)
      now = Time.current
      Exchange.insert({
                        entity_transaction_id: equal_total_entity_transaction.id,
                        cash_transaction_id: april_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 2_500,
                        starting_price: 2_500,
                        date: Time.zone.parse("2026-04-10 12:00:00"),
                        month: 4,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })
      Exchange.insert({
                        entity_transaction_id: equal_total_entity_transaction.id,
                        cash_transaction_id: april_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 2,
                        price: 3_500,
                        starting_price: 3_500,
                        date: Time.zone.parse("2026-04-11 12:00:00"),
                        month: 4,
                        year: 2026,
                        exchanges_count: 2,
                        created_at: now,
                        updated_at: now
                      })

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows.map { |row| row[:id] }).to be_empty
    end

    it "does not flag valid split allocations that reconcile the full card total" do
      user = create(:user, :random)
      alice = create(:entity, user:, entity_name: "ALICE")
      bob = create(:entity, user:, entity_name: "BOB")
      carol = create(:entity, user:, entity_name: "CAROL")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      bank_account = create(:user_bank_account, user:)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      april_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 04/2026 ] LALA - PP",
        date: Time.zone.parse("2026-04-10 12:00:00"),
        month: 4,
        year: 2026,
        price: 9_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 9_000, date: Time.zone.parse("2026-04-10 12:00:00"), month: 4, year: 2026)
        ]
      )
      april_return.categories = [ exchange_return_category ]
      april_return.save!

      card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Shared purchase",
        price: -9_000,
        card_installments: [
          build(:card_installment, number: 1, price: -4_500, date: Time.zone.parse("2026-03-10 12:00:00"), month: 4, year: 2026),
          build(:card_installment, number: 2, price: -4_500, date: Time.zone.parse("2026-04-10 12:00:00"), month: 5, year: 2026)
        ]
      )
      card.entity_transactions.destroy_all
      et_one = card.entity_transactions.create!(entity: alice, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      et_two = card.entity_transactions.create!(entity: bob, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      card.entity_transactions.create!(entity: carol, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      now = Time.current
      [ et_one, et_two, card.entity_transactions.find_by!(entity: carol) ].each_with_index do |entity_transaction, index|
        Exchange.insert({
                          entity_transaction_id: entity_transaction.id,
                          cash_transaction_id: april_return.id,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          bound_type: "card_bound",
                          number: index + 1,
                          price: 3_000,
                          starting_price: 3_000,
                          date: Time.zone.parse("2026-04-10 12:00:00"),
                          month: 4,
                          year: 2026,
                          exchanges_count: 1,
                          created_at: now,
                          updated_at: now
                        })
      end

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows).to eq([])
    end

    it "flags missing MOI on split allocations when the self-share is undeclared" do
      user = create(:user, :random)
      alice = create(:entity, user:, entity_name: "ALICE")
      bob = create(:entity, user:, entity_name: "BOB")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      bank_account = create(:user_bank_account, user:)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      april_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 04/2026 ] LALA - PP",
        date: Time.zone.parse("2026-04-10 12:00:00"),
        month: 4,
        year: 2026,
        price: 6_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 6_000, date: Time.zone.parse("2026-04-10 12:00:00"), month: 4, year: 2026)
        ]
      )
      april_return.categories = [ exchange_return_category ]
      april_return.save!

      card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Pizza",
        price: -9_000,
        card_installments: [
          build(:card_installment, number: 1, price: -4_500, date: Time.zone.parse("2026-03-10 12:00:00"), month: 4, year: 2026),
          build(:card_installment, number: 2, price: -4_500, date: Time.zone.parse("2026-04-10 12:00:00"), month: 5, year: 2026)
        ]
      )
      card.entity_transactions.destroy_all
      et_one = card.entity_transactions.create!(entity: alice, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      et_two = card.entity_transactions.create!(entity: bob, price: 3_000, price_to_be_returned: 3_000, is_payer: true)
      now = Time.current
      [ et_one, et_two ].each_with_index do |entity_transaction, index|
        Exchange.insert({
                          entity_transaction_id: entity_transaction.id,
                          cash_transaction_id: april_return.id,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          bound_type: "card_bound",
                          number: index + 1,
                          price: 3_000,
                          starting_price: 3_000,
                          date: Time.zone.parse("2026-04-10 12:00:00"),
                          month: 4,
                          year: 2026,
                          exchanges_count: 1,
                          created_at: now,
                          updated_at: now
                        })
      end

      rows = described_class.new(current_user: user, current_context: user.main_context).call

      expect(rows.map { |row| row[:id] }).to eq([ card.id ])
      expect(rows.first[:issues]).to contain_exactly("source_allocation_mismatch")
      expect(rows.first[:allocation_issue]).to eq({
                                                    transactable_type: "CardTransaction",
                                                    transactable_id: card.id,
                                                    description: "Pizza",
                                                    transaction_total: 9_000,
                                                    allocation_total: 6_000,
                                                    payer_total: 6_000,
                                                    missing_amount: 3_000,
                                                    has_moi_entity: false,
                                                    issue_code: "missing_moi_allocation"
                                                  })
    end

    it "does not flag source allocation when return percentage explains the payer amount" do
      user = create(:user, :random)
      entity = create(:entity, user:, entity_name: "VIH")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      bank_account = create(:user_bank_account, user:)
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "[ 07/2026 ] VIH - CARD",
        price: 66_900,
        cash_installments: [ build(:cash_installment, number: 1, price: 66_900) ]
      )
      exchange_return.categories = [ exchange_return_category ]
      exchange_return.save!

      card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "FOGAO E PANELA",
        price: -60_165,
        card_installments: [ build(:card_installment, number: 1, price: -60_165, month: 7, year: 2026) ]
      )
      entity_transaction = card.entity_transactions.first
      entity_transaction.update_columns(
        entity_id: entity.id,
        is_payer: true,
        price: 66_900,
        price_to_be_returned: 66_900,
        loan_return_percentage: 111.1942,
        exchanges_count: 1
      )
      Exchange.insert({
                        entity_transaction_id: entity_transaction.id,
                        cash_transaction_id: exchange_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 66_900,
                        starting_price: 66_900,
                        date: exchange_return.date,
                        month: exchange_return.month,
                        year: exchange_return.year,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      rows = described_class.new(current_user: user, current_context: user.main_context).call
      row = rows.find { |entry| entry[:id] == card.id }

      expect(row[:issues]).to be_empty
      expect(row[:allocation_issue]).to be_nil
      expect(row[:warnings]).to contain_exactly("projection_shape_mismatch")
    end

    it "filters pending rows by default and can return paid rows explicitly" do
      user = create(:user, :random)
      user_card = create(:user_card, :random, user:, card: create(:card, :random))

      pending_card = create(:card_transaction, user:, context: user.main_context, user_card:, description: "Pending broken", paid: false)
      pending_card.entity_transactions.first.update_columns(is_payer: true, price: 1_000, price_to_be_returned: 1_000)
      pending_card.update_column(:paid, false)
      create(:exchange, entity_transaction: pending_card.entity_transactions.first, exchange_type: :monetary, price: 500, month: 4, year: 2026)

      paid_card = create(:card_transaction, user:, context: user.main_context, user_card:, description: "Paid broken", paid: true)
      paid_card.entity_transactions.first.update_columns(is_payer: true, price: 1_000, price_to_be_returned: 1_000)
      paid_card.update_column(:paid, true)
      create(:exchange, entity_transaction: paid_card.entity_transactions.first, exchange_type: :monetary, price: 500, month: 4, year: 2026)

      default_rows = described_class.new(current_user: user, current_context: user.main_context).call
      paid_rows = described_class.new(current_user: user, current_context: user.main_context, status_filter: "paid").call

      expect(default_rows.map { |row| row[:id] }).to eq([ pending_card.id ])
      expect(paid_rows.map { |row| row[:id] }).to eq([ paid_card.id ])
    end
  end
end
