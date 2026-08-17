# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceMerges::ReallocationPlanner do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:, due_date_day: 12, days_until_due_date: 5) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:card_payment_category) { user.built_in_category("CARD PAYMENT") }

  def create_reference(month, year = 2026)
    create(
      :reference,
      user_card:,
      context:,
      month:,
      year:,
      reference_date: Date.new(year, month, 12),
      reference_closing_date: Date.new(year, month, 7)
    )
  end

  def create_invoice(reference, price: -1_000, paid: false)
    create(
      :cash_transaction,
      user:,
      context:,
      user_card:,
      user_bank_account: account,
      cash_transaction_type: "CardInstallment",
      date: reference.reference_date.end_of_day,
      month: reference.month,
      year: reference.year,
      price:,
      paid:,
      cash_installments: [
        build(
          :cash_installment,
          number: 1,
          date: reference.reference_date.end_of_day,
          month: reference.month,
          year: reference.year,
          price:,
          paid:
        )
      ],
      category_transactions: [ CategoryTransaction.new(category: card_payment_category) ],
      entity_transactions: []
    )
  end

  def create_card_installment(reference, invoice:, number: 1, count: 1, paid: false, transaction: nil)
    transaction ||= create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: reference.reference_closing_date - 1.day,
      month: reference.month,
      year: reference.year,
      price: invoice.price,
      card_installments: [
        build(
          :card_installment,
          number:,
          date: reference.reference_closing_date - 1.day,
          month: reference.month,
          year: reference.year,
          price: invoice.price,
          paid:
        )
      ],
      category_transactions: [],
      entity_transactions: []
    )
    installment = transaction.card_installments.find_by!(number:)
    installment.update_columns(
      cash_transaction_id: invoice.id,
      card_installments_count: count,
      month: reference.month,
      year: reference.year,
      paid:
    )
    installment.reload
  end

  def plan(source: "2026-08-01", target: "2026-09-01", selected_context: context, selected_card: user_card)
    described_class.new(user_card: selected_card, context: selected_context, source_date: source, target_date: target).call
  end

  def create_card_bound_exchange(reference, price: 500)
    transaction = create(:card_transaction, user:, context:, user_card:, month: reference.month, year: reference.year)
    create(
      :exchange,
      entity_transaction: transaction.entity_transactions.first,
      exchange_type: :monetary,
      bound_type: :card_bound,
      month: reference.month,
      year: reference.year,
      date: reference.reference_closing_date,
      price:
    )
  end

  it "maps every bucket through the latest persisted installment and records tail requirements" do
    august = create_reference(8)
    september = create_reference(9)
    december = create_reference(12)
    august_invoice = create_invoice(august)
    september_invoice = create_invoice(september)
    december_invoice = create_invoice(december)
    august_installment = create_card_installment(august, invoice: august_invoice, number: 8, count: 12)
    september_installment = create_card_installment(september, invoice: september_invoice, number: 9, count: 12)
    december_installment = create_card_installment(december, invoice: december_invoice, number: 12, count: 12)

    result = plan

    expect(result).to be_eligible
    expect(result.buckets.map(&:source_date)).to eq(
      [ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1), Date.new(2026, 11, 1), Date.new(2026, 12, 1) ]
    )
    expect(result.installment_ids).to contain_exactly(august_installment.id, september_installment.id, december_installment.id)
    expect(result.earliest_affected_date).to eq(Date.new(2026, 8, 1))
    expect(result.latest_affected_date).to eq(Date.new(2026, 12, 1))
    expect(result.tail_date).to eq(Date.new(2027, 1, 1))

    august_bucket = result.buckets.first
    september_bucket = result.buckets.second
    december_bucket = result.buckets.last
    expect(august_bucket).to have_attributes(
      destination_date: Date.new(2026, 9, 1),
      destination_invoice_id: september_invoice.id,
      destination_reference_id: september.id
    )
    expect(september_bucket).to be_destination_invoice_required
    expect(september_bucket).to be_destination_reference_required
    expect(december_bucket).to be_destination_invoice_required
    expect(december_bucket).to be_destination_reference_required
    numeric_lock_order = result.lock_keys.sort_by do |key|
      record_type, record_id = key.split(":", 2)
      [ record_type, record_id.to_i ]
    end
    expect(result.lock_keys).to eq(numeric_lock_order)
    expect(result.digest).to match(/\A[0-9a-f]{64}\z/)
  end

  it "keeps empty calendar gaps while moving each occupied bucket exactly one month" do
    august = create_reference(8)
    september = create_reference(9)
    november = create_reference(11)
    august_installment = create_card_installment(august, invoice: create_invoice(august))
    create_card_installment(september, invoice: create_invoice(september))
    november_installment = create_card_installment(november, invoice: create_invoice(november))

    result = plan

    expect(result).to be_eligible
    expect(result.buckets.map(&:source_date)).to eq(
      [ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1), Date.new(2026, 11, 1) ]
    )
    expect(result.buckets.third).not_to be_occupied
    expect(result.buckets.first.installment_ids).to eq([ august_installment.id ])
    expect(result.buckets.last.installment_ids).to eq([ november_installment.id ])
  end

  it "reports paid installments and invoices as blockers without writing data" do
    august = create_reference(8)
    september = create_reference(9)
    august_invoice = create_invoice(august)
    september_invoice = create_invoice(september)
    paid_installment = create_card_installment(august, invoice: august_invoice, paid: true)
    create_card_installment(september, invoice: september_invoice)
    version_count = AuditVersion.count

    result = plan

    expect(result).to be_conflict
    expect(result.issues.map(&:code)).to include(:paid_installments)
    expect(result.issues.find { |issue| issue.code == :paid_installments }.details[:ids]).to include(paid_installment.id.to_s)
    expect(AuditVersion.count).to eq(version_count)
  end

  it "allows an unpaid future installment when only earlier installments have paid history" do
    july = create_reference(7)
    august = create_reference(8)
    september = create_reference(9)
    invoices = [ july, august, september ].map { |reference| create_invoice(reference) }
    transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: july.reference_closing_date - 1.day,
      month: july.month,
      year: july.year,
      price: -2_000,
      card_installments: [
        build(:card_installment, number: 1, date: july.reference_closing_date - 1.day, month: 7, year: 2026, price: -1_000, paid: false),
        build(:card_installment, number: 2, date: august.reference_closing_date - 1.day, month: 8, year: 2026, price: -1_000, paid: false)
      ],
      category_transactions: [],
      entity_transactions: []
    )
    transaction.card_installments.order(:number).zip(invoices.first(2)).each do |installment, invoice|
      installment.update_columns(cash_transaction_id: invoice.id)
    end
    transaction.card_installments.order(:number).first.update_columns(paid: true)

    result = plan

    expect(result).to be_eligible
    expect(result.installment_ids).to include(transaction.card_installments.order(:number).last.id)
    expect(result.issues.map(&:code)).not_to include(:paid_installments)
  end

  it "includes monetary card-bound exchanges and excludes unrelated card and context rows" do
    august = create_reference(8)
    september = create_reference(9)
    august_invoice = create_invoice(august)
    september_invoice = create_invoice(september)
    create_card_installment(august, invoice: august_invoice)
    create_card_installment(september, invoice: september_invoice)

    source_exchange = create_card_bound_exchange(august)
    other_card = create(:user_card, :random, user:)
    unrelated_transaction = create(:card_transaction, user:, context:, user_card: other_card, month: 8, year: 2026)
    unrelated_exchange = create(
      :exchange,
      entity_transaction: unrelated_transaction.entity_transactions.first,
      exchange_type: :monetary,
      bound_type: :card_bound,
      month: 8,
      year: 2026,
      date: august.reference_closing_date,
      price: 700
    )

    result = plan

    expect(result.exchange_ids).to include(source_exchange.id)
    expect(result.exchange_ids).not_to include(unrelated_exchange.id)
  end

  it "blocks paid exchange projections and duplicate canonical invoices" do
    august = create_reference(8)
    september = create_reference(9)
    august_invoice = create_invoice(august)
    september_invoice = create_invoice(september)
    create_card_installment(august, invoice: august_invoice)
    create_card_installment(september, invoice: september_invoice)
    exchange = create_card_bound_exchange(august)
    exchange.cash_transaction.cash_installments.first.update_columns(paid: true)
    duplicate_invoice = create_invoice(september, price: -500)

    result = plan

    expect(result).to be_conflict
    expect(result.issues.map(&:code)).to include(:locked_exchange_projections, :duplicate_invoices, :missing_root)
    expect(result.issues.find { |issue| issue.code == :duplicate_invoices }.details[:dates]).to eq("2026-09-01")
    expect(result.lock_keys).to include("CashTransaction:#{duplicate_invoice.id}")
  end

  it "reports invalid direction, missing roots, and context ownership mismatches" do
    other_user = create(:user, :random)

    invalid_direction = plan(source: "2026-09-01", target: "2026-08-01")
    missing_roots = plan
    wrong_context = plan(selected_context: other_user.main_context)

    expect(invalid_direction.issues.map(&:code)).to include(:not_forward_adjacent)
    expect(missing_roots.issues.map(&:code)).to include(:missing_root, :empty_shift)
    expect(wrong_context.issues.map(&:code)).to include(:context_mismatch)
  end

  it "rejects invalid dates without raising" do
    result = plan(source: nil, target: "not-a-month")

    expect(result).to be_conflict
    expect(result.issues.map(&:code)).to include(:invalid_date, :empty_shift)
  end
end
