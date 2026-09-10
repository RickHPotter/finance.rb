# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::UserCardMovement do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:query_state) { Reports::QueryState.new({ from_date: "2026-07-01", to_date: "2026-08-31" }) }

  before do
    july = create(:reference, user_card:, context:, month: 7, year: 2026, reference_date: Date.new(2026, 7, 12))
    august = create(:reference, user_card:, context:, month: 8, year: 2026, reference_date: Date.new(2026, 8, 14))
    july.update_columns(reference_closing_date: Date.new(2026, 7, 5))
    august.update_columns(reference_closing_date: Date.new(2026, 8, 7))
  end

  it "reconciles billing periods while retaining distinct dates and generated identities" do
    one_off = create_transaction(
      description: "One-off purchase",
      price: -1_000,
      date: Date.new(2026, 6, 28),
      installments: [ installment(number: 1, price: -1_000, date: Date.new(2026, 6, 28), month: 7, paid: true) ]
    )
    spread = create_transaction(
      description: "Spread purchase",
      price: -600,
      date: Date.new(2026, 6, 29),
      installments: [
        installment(number: 1, price: -300, date: Date.new(2026, 6, 29), month: 7),
        installment(number: 2, price: -300, date: Date.new(2026, 7, 29), month: 8)
      ]
    )
    advance = create_transaction(
      description: "Card advance",
      price: -500,
      date: Date.new(2026, 6, 30),
      installments: [ installment(number: 1, price: -500, date: Date.new(2026, 6, 30), month: 7) ],
      categories: [ user.built_in_category("CARD ADVANCE") ]
    )
    create_transaction(
      description: "Other card",
      price: -9_000,
      date: Date.new(2026, 6, 30),
      installments: [ installment(number: 1, price: -9_000, date: Date.new(2026, 6, 30), month: 7) ],
      target_card: create(:user_card, :random, user:)
    )
    create_transaction(
      description: "Other context",
      price: -8_000,
      date: Date.new(2026, 6, 30),
      installments: [ installment(number: 1, price: -8_000, date: Date.new(2026, 6, 30), month: 7) ],
      target_context: create(:context, user:)
    )

    payload = described_class.new(context:, user_card:, query_state:).call

    expect(payload[:resource]).to eq(type: "UserCard", id: user_card.id, label: user_card.user_card_name)
    expect(payload[:summary]).to include(net_cents: -2_100)
    expect(payload.dig(:summary, :outcome)).to include(amount_cents: 2_100, source_count: 4)
    expect(payload[:payment_states]).to contain_exactly(
      include(key: :paid, net_cents: -1_000),
      include(key: :pending, net_cents: -1_100)
    )
    expect(payload[:buckets]).to match(
      [ include(key: "2026-07", net_cents: -1_800), include(key: "2026-08", net_cents: -300) ]
    )
    expect(payload[:breakdowns]).to contain_exactly(
      include(key: :ordinary, net_cents: -1_600),
      include(key: :advance, net_cents: -500)
    )
    expect(payload[:details].size).to eq(4)

    one_off_detail = payload[:details].find { |detail| detail[:transaction_id] == one_off.id }
    expect(one_off_detail).to include(
      purchase_date: "2026-06-28",
      installment_date: "2026-06-28",
      billing_period: "2026-07",
      paid: true
    )
    expect(one_off_detail[:invoice]).to include(
      reference_id: user_card.references.find_by!(context:, month: 7, year: 2026).id,
      closing_date: "2026-07-05",
      due_date: "2026-07-12"
    )
    expect(one_off_detail.dig(:generated_payment, :cash_transaction_id)).to eq(one_off.card_installments.sole.cash_transaction_id)

    spread_details = payload[:details].select { |detail| detail[:transaction_id] == spread.id }
    expect(spread_details.pluck(:installment_date, :billing_period, :installment_number)).to eq(
      [ [ "2026-06-29", "2026-07", 1 ], [ "2026-07-29", "2026-08", 2 ] ]
    )
    expect(spread_details.last[:invoice]).to include(closing_date: "2026-08-07", due_date: "2026-08-14")

    advance_detail = payload[:details].find { |detail| detail[:transaction_id] == advance.id }
    expect(advance_detail).to include(family: :advance)
    expect(advance.advance_cash_transaction_id).to be_present
    expect(advance_detail[:advance]).to include(active: true, cash_transaction_id: advance.advance_cash_transaction_id)
    expect(advance_detail.dig(:generated_payment, :cash_transaction_id)).not_to eq(advance.advance_cash_transaction_id)
    expect(payload[:details].pluck(:identity)).to eq(payload[:details].pluck(:identity).uniq)
    expect(context.cash_installments.count).to be > payload[:details].size

    exact_query = Rack::Utils.parse_nested_query(URI.parse(advance_detail[:path]).query)
    expect(exact_query.dig("card_transaction", "card_installment_ids")).to eq([ advance.card_installments.sole.id.to_s ])
  end

  it "applies installment paid state and direction without writing projections or audit history" do
    transaction = create_transaction(
      description: "Read-only report",
      price: -1_000,
      date: Date.new(2026, 6, 28),
      installments: [ installment(number: 1, price: -1_000, date: Date.new(2026, 6, 28), month: 7, paid: false) ]
    )
    filtered_state = Reports::QueryState.new(
      { from_date: "2026-07-01", to_date: "2026-07-31", paid_state: "pending", direction: "outcome" }
    )
    timestamps = [ transaction.updated_at, transaction.card_installments.sole.updated_at, transaction.card_installments.sole.cash_transaction.updated_at ]

    expect do
      payload = described_class.new(context:, user_card:, query_state: filtered_state).call
      expect(payload.dig(:summary, :outcome)).to include(amount_cents: 1_000, source_count: 1)
      expect(payload.dig(:summary, :income, :amount_cents)).to eq(0)
    end.not_to change(AuditVersion, :count)

    expect([ transaction.reload.updated_at, transaction.card_installments.sole.reload.updated_at,
             transaction.card_installments.sole.cash_transaction.reload.updated_at ]).to eq(timestamps)
  end

  it "keeps user-card report query count bounded as rows grow" do
    create_transaction(
      description: "Baseline",
      price: -100,
      date: Date.new(2026, 6, 28),
      installments: [ installment(number: 1, price: -100, date: Date.new(2026, 6, 28), month: 7) ]
    )
    baseline_count = count_select_queries { described_class.new(context:, user_card:, query_state:).call }

    3.times do |index|
      create_transaction(
        description: "Expanded #{index}",
        price: -(index + 2) * 100,
        date: Date.new(2026, 6, 28),
        installments: [ installment(number: 1, price: -(index + 2) * 100, date: Date.new(2026, 6, 28), month: 7) ]
      )
    end
    expanded_count = count_select_queries { described_class.new(context:, user_card:, query_state:).call }

    expect(expanded_count).to eq(baseline_count)
  end

  private

  def installment(number:, price:, date:, month:, paid: false)
    build(:card_installment, number:, price:, date:, month:, year: 2026, paid:)
  end

  def create_transaction(description:, price:, date:, installments:, categories: [], target_card: user_card, target_context: context)
    attributes = {
      user_card: target_card,
      description:,
      date:,
      month: installments.first.month,
      year: installments.first.year,
      price:,
      paid: installments.all?(&:paid?),
      card_installments: installments
    }
    if categories.any? { |category| category.category_name == "CARD ADVANCE" }
      transaction = CardTransaction.new_advanced_payment(user, attributes, context: target_context)
      transaction.save!
      return transaction
    end

    create(
      :card_transaction,
      user:,
      context: target_context,
      **attributes,
      category_transactions: [],
      entity_transactions: []
    )
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
