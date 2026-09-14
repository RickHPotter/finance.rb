# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledgers::Query, type: :service do
  let(:user) { create(:user, :random) }
  let(:entity) { create(:entity, user:, entity_name: "CRÍSTIAN PENS") }
  let(:context) { user.main_context }
  let(:access) { Ledgers::Access::Result.new(user:, entity:, context:, share: nil) }

  describe "cash membership" do
    it "reconciles unique rows, counts, totals, paid state, search, Context, and special categories" do
      first = create_cash_installment(description: "CAFÉ CRÍSTIAN", category_name: "EXCHANGE RETURN", price: -1000, paid: false)
      first.cash_transaction.category_transactions.create!(category: create(:category, :random, user:))
      first.cash_transaction.entity_transactions.create!(entity: create(:entity, :random, user:), is_payer: false, price: 0, price_to_be_returned: 0)
      second = create_cash_installment(description: "SECOND RETURN", category_name: "BORROW RETURN", price: -2000, paid: true)
      create_cash_installment(description: "OTHER ENTITY", entity: create(:entity, :random, user:), price: -3000)
      derived = create(:context, user:, source_context: context, name: "Derived ledger")
      create_cash_installment(description: "OTHER CONTEXT", context: derived, price: -4000)
      create_cash_installment(description: "OTHER CATEGORY", category_name: "FOOD", price: -5000)

      result = query(kind: :cash, params: { month_year: "202609" })

      expect(result.rows.ids).to eq([ first.id, second.id ])
      expect(result).to have_attributes(total_count: 2, total_amount: -3000)
      expect(result.count_by_month_year.fetch(202_609)).to have_attributes(count: 2, total: -3000)

      searched = query(kind: :cash, params: { month_year: "202609", search_term: "cafe cristian" })
      expect(searched.rows.ids).to eq([ first.id ])

      pending = query(kind: :cash, params: { month_year: "202609", paid: false, pending: true })
      expect(pending.rows.ids).to eq([ first.id ])
    end

    it "bounds row chunks while retaining totals from the same source relation" do
      first = create_cash_installment(description: "FIRST", price: -1000)
      second = create_cash_installment(description: "SECOND", price: -2000)

      result = query(kind: :cash, params: { month_year: "202609", per_page: 1 })

      expect(result.rows.ids).to eq([ first.id ])
      expect(result).to have_attributes(total_count: 2, total_amount: -3000, page: 1, per_page: 1)
      expect(result.rows.ids).not_to include(second.id)
    end

    it "returns empty membership for another owner's bank-account filter" do
      create_cash_installment(description: "PRIVATE CASH", price: -1000)
      foreign_account = create(:user_bank_account, :random, user: create(:user, :random), bank: create(:bank, :random))

      result = query(
        kind: :cash,
        params: { month_year: "202609", cash_transaction: { user_bank_account_id: foreign_account.id } }
      )

      expect(result.rows).to be_empty
      expect(result.months).to be_empty
    end

    it "returns identical financial membership for internal and external access" do
      installment = create_cash_installment(description: "SHARED MEMBERSHIP", price: -1000)
      share = Ledgers::Shares::Create.call(entity:, context:)
      external_access = Ledgers::Access::External.call(token: share.token)
      state = Ledgers::QueryState.new(kind: :cash, params: { month_year: "202609" })

      internal_result = described_class.call(access:, state:)
      external_result = described_class.call(access: external_access, state:)

      expect(internal_result.rows.ids).to eq([ installment.id ])
      expect(external_result.rows.ids).to eq(internal_result.rows.ids)
      expect(external_result.months).to eq(internal_result.months)
    end

    it "keeps query count bounded when allocation multiplicity grows" do
      installment = create_cash_installment(description: "BOUNDED QUERY", price: -1000)
      state = Ledgers::QueryState.new(kind: :cash, params: { month_year: "202609" })
      baseline = database_query_count { described_class.call(access:, state:).rows.each { |row| row.cash_transaction.categories.to_a } }

      3.times do
        installment.cash_transaction.category_transactions.create!(category: create(:category, :random, user:))
        installment.cash_transaction.entity_transactions.create!(
          entity: create(:entity, :random, user:),
          is_payer: false,
          price: 0,
          price_to_be_returned: 0
        )
      end

      multiplied = database_query_count { described_class.call(access:, state:).rows.each { |row| row.cash_transaction.categories.to_a } }

      expect(multiplied).to eq(baseline)
      expect(multiplied).to be <= 10
    end
  end

  describe "card membership" do
    it "reconciles unique EXCHANGE rows, counts, totals, Context, and Entity" do
      first = create_card_installment(description: "CARD LEDGER", price: -1250)
      first.card_transaction.category_transactions.create!(category: create(:category, :random, user:))
      first.card_transaction.entity_transactions.create!(entity: create(:entity, :random, user:), is_payer: false, price: 0, price_to_be_returned: 0)
      create_card_installment(description: "OTHER ENTITY CARD", entity: create(:entity, :random, user:), price: -2000)
      derived = create(:context, user:, source_context: context, name: "Derived card ledger")
      create_card_installment(description: "OTHER CONTEXT CARD", context: derived, price: -3000)

      result = query(kind: :card, params: { month_year: "202609" })

      expect(result.rows.ids).to eq([ first.id ])
      expect(result).to have_attributes(total_count: 1, total_amount: -1250)
      expect(result.count_by_month_year.fetch(202_609)).to have_attributes(count: 1, total: -1250)
    end

    it "scopes card filters through the authorized owner" do
      create_card_installment(description: "PRIVATE CARD", price: -1250)
      foreign_user = create(:user, :random)
      foreign_card = create(:user_card, :random, user: foreign_user, card: create(:card, :random, bank: create(:bank, :random)))

      result = query(kind: :card, params: { month_year: "202609", card_transaction: { user_card_id: foreign_card.id } })

      expect(result.rows).to be_empty
      expect(result.months).to be_empty
      expect(result.user_card).to be_nil
    end

    it "applies an authorized card filter to external ledger rows" do
      selected = create_card_installment(description: "SELECTED CARD", price: -1250)
      create_card_installment(description: "OTHER CARD", price: -2000)
      share = Ledgers::Shares::Create.call(entity:, context:)
      external_access = Ledgers::Access::External.call(token: share.token)
      state = Ledgers::QueryState.new(
        kind: :card,
        params: { month_year: "202609", card_transaction: { user_card_id: selected.card_transaction.user_card_id } }
      )

      result = described_class.call(access: external_access, state:)

      expect(result.rows.ids).to eq([ selected.id ])
      expect(result.user_card).to eq(selected.card_transaction.user_card)
    end
  end

  private

  def query(kind:, params:)
    state = Ledgers::QueryState.new(kind:, params:)
    described_class.call(access:, state:)
  end

  def create_cash_installment(description:, price:, paid: false, category_name: "EXCHANGE RETURN", entity: self.entity, context: self.context)
    account = create(:user_bank_account, :random, user:, bank: create(:bank, :random))
    category = user.categories.find_by(category_name:) || create(:category, :random, user:, category_name:)
    transaction = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description:,
      date: Time.zone.local(2026, 9, 10, 12),
      month: 9,
      year: 2026,
      price:,
      cash_installments: [],
      category_transactions_attributes: [ { category_id: category.id } ],
      entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
      cash_installments_attributes: [ { number: 1, date: Time.zone.local(2026, 9, 10, 12), month: 9, year: 2026, price:, paid: } ]
    )
    transaction.cash_installments.first
  end

  def create_card_installment(description:, price:, entity: self.entity, context: self.context)
    user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: create(:bank, :random)))
    transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      description:,
      date: Time.zone.local(2026, 8, 10, 12),
      month: 9,
      year: 2026,
      price:,
      card_installments: [ build(:card_installment, number: 1, date: Time.zone.local(2026, 8, 10, 12), month: 9, year: 2026, price:) ]
    )
    transaction.category_transactions.destroy_all
    transaction.entity_transactions.destroy_all
    transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
    transaction.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    transaction.card_installments.first
  end

  def database_query_count(&)
    count = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA CACHE]) || payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &)
    count
  end
end
