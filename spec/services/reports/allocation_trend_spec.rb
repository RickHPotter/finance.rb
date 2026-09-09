# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::AllocationTrend do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, user:, category_name: "FOOD") }
  let(:entity) { create(:entity, user:, entity_name: "ANA") }
  let(:query_state) do
    Reports::QueryState.new({ from_date: "2026-07-01", to_date: "2026-09-30", granularity: "month" })
  end

  describe Reports::CategoryTrend do
    subject(:payload) { described_class.new(context:, category:, query_state:).call }

    it "reconciles mixed cash and card ordinary rows into buckets, counterpart bundles, and typed drill-downs" do
      second_category = create(:category, user:, category_name: "ESSENTIAL")
      second_entity = create(:entity, user:, entity_name: "BRUNO")
      cash_transaction = create_cash_transaction(price: 12_345, categories: [ category, second_category ], entities: [ entity, second_entity ])
      card_transaction = create_card_transaction(price: -4_567, categories: [ category, second_category ], entities: [ entity, second_entity ])

      expect(payload[:resource]).to eq(type: "Category", id: category.id, label: "FOOD")
      expect(payload[:summary]).to include(net_cents: 7_778)
      expect(payload.dig(:summary, :income)).to include(amount_cents: 12_345, source_count: 1)
      expect(payload.dig(:summary, :outcome)).to include(amount_cents: 4_567, source_count: 1)
      expect(payload[:buckets].pluck(:key)).to eq(%w[2026-07 2026-08 2026-09])
      expect(payload[:buckets].first).to include(net_cents: 7_778)
      expect(payload[:buckets].drop(1)).to all(include(net_cents: 0))
      expect(payload[:breakdowns]).to contain_exactly(
        include(key: "entities:#{entity.id}+#{second_entity.id}", label: "ANA + BRUNO", net_cents: 7_778)
      )

      cash_sources = payload.dig(:summary, :income, :sources, :cash)
      card_sources = payload.dig(:summary, :outcome, :sources, :card)
      expect(cash_sources).to include(count: 1, amount_cents: 12_345)
      expect(card_sources).to include(count: 1, amount_cents: 4_567)
      expect(installment_ids(cash_sources.dig(:chunks, 0, :path), "cash_transaction", "cash_installment_ids"))
        .to eq([ cash_transaction.cash_installments.sole.id.to_s ])
      expect(installment_ids(card_sources.dig(:chunks, 0, :path), "card_transaction", "card_installment_ids"))
        .to eq([ card_transaction.card_installments.sole.id.to_s ])

      return_to = Rack::Utils.parse_nested_query(URI.parse(cash_sources.dig(:chunks, 0, :path)).query).fetch("return_to")
      expect(Navigation::Dashboard.new(raw: return_to, current_user: user, current_context: context).destination).to eq(return_to)
    end

    it "excludes special movement, other allocations, other contexts, and nonmatching paid state" do
      included = create_cash_transaction(price: -1_000, categories: [ category ], entities: [ entity ], paid: false)
      create_cash_transaction(price: -2_000, categories: [ category ], entities: [ entity ], paid: true)
      create_cash_transaction(price: -3_000, categories: [ create(:category, :random, user:) ], entities: [ entity ])
      create_cash_transaction(price: -4_000, categories: [ category ], entities: [ entity ], context: create(:context, user:))
      transfer = create_cash_transaction(price: -5_000, categories: [ category ], entities: [ entity ])
      create(:category_transaction, transactable: transfer, category: user.built_in_category("EXCHANGE"))
      pending_state = Reports::QueryState.new(
        { from_date: "2026-07-01", to_date: "2026-07-31", paid_state: "pending", direction: "outcome" }
      )

      result = described_class.new(context:, category:, query_state: pending_state).call

      expect(result.dig(:summary, :outcome)).to include(amount_cents: 1_000, source_count: 1)
      path = result.dig(:summary, :outcome, :sources, :cash, :chunks, 0, :path)
      expect(installment_ids(path, "cash_transaction", "cash_installment_ids")).to eq([ included.cash_installments.sole.id.to_s ])
      expect(result.dig(:summary, :income, :amount_cents)).to eq(0)
    end
  end

  describe Reports::EntityTrend do
    subject(:payload) { described_class.new(context:, entity:, query_state:).call }

    it "uses deterministic category bundles with the canonical chart presentation" do
      second_category = create(:category, user:, category_name: "TRANSPORT", colour: "#dc2626")
      create_cash_transaction(price: -2_500, categories: [ second_category, category ], entities: [ entity ])

      breakdown = payload[:breakdowns].sole
      presentation = CategoryColours::Presentation.bundle([ category, second_category ].sort_by { |record| [ record.name, record.id ] }).chart_payload

      expect(payload[:resource]).to eq(type: "Entity", id: entity.id, label: "ANA")
      expect(breakdown).to include(
        key: "categories:#{[ category.id, second_category.id ].sort_by { |id| user.categories.find(id).name }.join('+')}",
        label: "FOOD + TRANSPORT",
        net_cents: -2_500,
        **presentation.except(:segments)
      )
      expect(breakdown[:segments]).to match_array(presentation[:segments])
    end

    it "represents missing counterpart allocations with a stable neutral bundle" do
      create_cash_transaction(price: 1_250, categories: [], entities: [ entity ])

      expect(payload[:breakdowns]).to contain_exactly(
        include(
          key: "category:unassigned",
          label: I18n.t("balances.monthly_analysis.unassigned"),
          background: CategoryColours::Presentation.neutral.background,
          foreground: CategoryColours::Presentation.neutral.foreground
        )
      )
    end
  end

  it "keeps allocation report queries bounded as the number of rows grows" do
    create_cash_transaction(price: -100, categories: [ category ], entities: [ entity ])
    create_card_transaction(price: -200, categories: [ category ], entities: [ entity ])
    baseline_count = count_select_queries { Reports::CategoryTrend.new(context:, category:, query_state:).call }

    3.times do |index|
      create_cash_transaction(price: -(index + 1) * 100, categories: [ category ], entities: [ entity ])
      create_card_transaction(price: -(index + 1) * 200, categories: [ category ], entities: [ entity ])
    end

    expanded_count = count_select_queries { Reports::CategoryTrend.new(context:, category:, query_state:).call }

    expect(expanded_count).to eq(baseline_count)
  end

  private

  def create_cash_transaction(price:, categories:, entities:, paid: false, context: self.context)
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price:,
      paid:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Date.new(2026, 7, 10), month: 7, year: 2026, paid:) ],
      category_transactions: categories.map { |record| CategoryTransaction.new(category: record) },
      entity_transactions: entities.map { |record| EntityTransaction.new(entity: record, price: 0, price_to_be_returned: 0, is_payer: false) }
    )
  end

  def create_card_transaction(price:, categories:, entities:, paid: false)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: Date.new(2026, 6, 10),
      month: 7,
      year: 2026,
      price:,
      paid:,
      card_installments: [ build(:card_installment, number: 1, price:, date: Date.new(2026, 6, 10), month: 7, year: 2026, paid:) ],
      category_transactions: categories.map { |record| CategoryTransaction.new(category: record) },
      entity_transactions: entities.map { |record| EntityTransaction.new(entity: record, price: 0, price_to_be_returned: 0, is_payer: false) }
    )
  end

  def installment_ids(path, owner_key, installment_key)
    query = Rack::Utils.parse_nested_query(URI.parse(path).query)
    query.fetch(owner_key).fetch(installment_key)
  end

  def count_select_queries(&)
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, data|
      queries << data[:sql] if data[:sql].start_with?("SELECT") && !data[:cached]
    end

    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &)
    end
    queries.size
  end
end
