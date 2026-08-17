# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceMerges::ReallocationApply do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:, due_date_day: 12, days_until_due_date: 5) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:card_payment_category) { user.built_in_category("CARD PAYMENT") }
  let(:exchange_category) { user.built_in_category("EXCHANGE") }

  def create_reference(month, year)
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

  def create_invoice(reference, price: -1_000)
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
      paid: false,
      cash_installments: [
        build(
          :cash_installment,
          number: 1,
          date: reference.reference_date.end_of_day,
          month: reference.month,
          year: reference.year,
          price:,
          paid: false
        )
      ],
      category_transactions: [ CategoryTransaction.new(category: card_payment_category) ],
      entity_transactions: []
    )
  end

  def create_year_transaction
    references = (1..12).map { |month| create_reference(month, 2026) }
    references.each { |reference| create_invoice(reference) }
    [ create_transaction_for(references), references ]
  end

  def create_transaction_for(references)
    installments = references.map.with_index do |reference, index|
      build(
        :card_installment,
        number: index + 1,
        date: reference.reference_closing_date - 1.day,
        month: reference.month,
        year: reference.year,
        price: -1_000,
        paid: false
      )
    end
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: references.first.reference_closing_date - 1.day,
      month: 1,
      year: 2026,
      price: -12_000,
      card_installments: installments,
      category_transactions: [],
      entity_transactions: []
    )
  end

  def build_plan
    ReferenceMerges::ReallocationPlanner.new(
      user_card:,
      context:,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    ).call
  end

  def attach_card_bound_exchanges(transaction, references)
    transaction.categories << exchange_category
    entity_transaction = create(
      :entity_transaction,
      transactable: transaction,
      entity: create(:entity, :random, user:),
      is_payer: true,
      price: transaction.price,
      price_to_be_returned: transaction.price.abs
    )
    references.map.with_index do |reference, index|
      create(
        :exchange,
        entity_transaction:,
        number: index + 1,
        exchange_type: :monetary,
        bound_type: :card_bound,
        month: reference.month,
        year: reference.year,
        date: reference.reference_date,
        price: (index + 1) * 500
      )
    end
  end

  it "reallocates installments 8 through 12 into September through January without changing their economics" do
    transaction, references = create_year_transaction
    august_reference = references.fetch(7)
    september_reference = references.fetch(8)
    original_target_closing_date = september_reference.reference_closing_date
    original_rows = transaction.card_installments.order(:number).map do |installment|
      installment.attributes.slice(
        "id", "card_transaction_id", "number", "card_installments_count", "price", "starting_price", "date", "month", "year"
      )
    end
    plan = build_plan

    result = nil
    expect { result = described_class.new(plan:).call }.to change { AuditOperation.where(source: :web, result: :committed).count }.by(1)

    expect(result).to be_applied
    expect(result.operation.metadata).to include(
      "reference_merge_mode" => Logic::References::REALLOCATE_INSTALLMENTS,
      "user_card_id" => user_card.id,
      "context_id" => context.id,
      "source_reference" => "2026-08-01",
      "target_reference" => "2026-09-01",
      "tail_reference" => "2027-01-01"
    )
    expect(result.operation.audit_versions.pluck(:item_subtype).uniq).to include("Reference", "CashTransaction", "CardInstallment", "CashInstallment")
    rows = transaction.card_installments.reload.order(:number)
    expect(rows.first(7).map { |row| [ row.month, row.year ] }).to eq((1..7).map { |month| [ month, 2026 ] })
    expect(rows.last(5).map { |row| [ row.month, row.year ] }).to eq([ [ 9, 2026 ], [ 10, 2026 ], [ 11, 2026 ], [ 12, 2026 ], [ 1, 2027 ] ])

    rows.zip(original_rows).each do |row, original|
      expect(row.attributes.slice("id", "card_transaction_id", "number", "card_installments_count", "price", "starting_price")).to eq(
        original.slice("id", "card_transaction_id", "number", "card_installments_count", "price", "starting_price")
      )
      expected_date = original["number"] >= 8 ? original["date"].next_month : original["date"]
      expect(row.date).to eq(expected_date)
    end

    expect(user_card.references).not_to exist(context:, month: 8, year: 2026)
    expect(user_card.references).to exist(context:, month: 1, year: 2027)
    expect(user_card.unpaid_invoices(context:)).not_to exist(month: 8, year: 2026)
    expect(user_card.unpaid_invoices(context:)).to exist(month: 1, year: 2027)
    (9..12).each do |month|
      invoices = user_card.unpaid_invoices(context:).where(month:, year: 2026)
      expect(invoices.count).to eq(1)
      expect(invoices.sole).to have_attributes(price: -1_000, cash_installments_count: 1)
      expect(invoices.sole.cash_installments.sole.price).to eq(-1_000)
    end
    january_invoice = user_card.unpaid_invoices(context:).find_by!(month: 1, year: 2027)
    expect(january_invoice).to have_attributes(price: -1_000, cash_installments_count: 1)
    expect(january_invoice.cash_installments.sole.price).to eq(-1_000)
    expect(september_reference.reload.reference_closing_date).to eq(august_reference.reference_closing_date)
    expect(september_reference.reference_closing_date).not_to eq(original_target_closing_date)
  end

  it "moves occupied buckets by one calendar month without collapsing an empty gap" do
    august = create_reference(8, 2026)
    september = create_reference(9, 2026)
    november = create_reference(11, 2026)
    [ august, september, november ].each { |reference| create_invoice(reference) }
    create_transaction_for([ august, september, november ])

    result = described_class.new(plan: build_plan).call

    expect(result).to be_applied
    expect(user_card.card_installments.order(:number).pluck(:month, :year)).to eq([ [ 9, 2026 ], [ 10, 2026 ], [ 12, 2026 ] ])
    expect(user_card.unpaid_invoices(context:).where(year: 2026).order(:month).pluck(:month)).to eq([ 9, 10, 12 ])
    expect(user_card.references.where(context:, year: 2026).order(:month).pluck(:month)).to include(9, 10, 11, 12)
  end

  it "moves an unpaid final installment after paid history and normalizes a drifted schedule date" do
    july = create_reference(7, 2026)
    august = create_reference(8, 2026)
    september = create_reference(9, 2026)
    invoices = [ july, august, september ].map { |reference| create_invoice(reference) }
    transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: Date.new(2026, 5, 29),
      month: 7,
      year: 2026,
      price: -2_000,
      card_installments: [
        build(:card_installment, number: 1, date: Date.new(2026, 5, 29), month: 7, year: 2026, price: -1_000, paid: false),
        build(:card_installment, number: 2, date: Date.new(2026, 6, 29), month: 8, year: 2026, price: -1_000, paid: false)
      ],
      category_transactions: [],
      entity_transactions: []
    )
    transaction.card_installments.order(:number).zip(invoices.first(2)).each do |installment, invoice|
      installment.update_columns(cash_transaction_id: invoice.id)
    end
    paid_installment, source_installment = transaction.card_installments.order(:number)
    paid_installment.update_columns(paid: true)

    target_transaction = create_transaction_for([ september ])
    target_installment = target_transaction.card_installments.sole
    target_installment.update_columns(date: Time.zone.local(2026, 7, 29), cash_transaction_id: invoices.last.id)

    result = described_class.new(plan: build_plan).call

    expect(result).to be_applied
    expect(paid_installment.reload).to have_attributes(date: Time.zone.local(2026, 5, 29), month: 7, year: 2026, paid: true)
    expect(source_installment.reload).to have_attributes(date: Time.zone.local(2026, 8, 29), month: 9, year: 2026, paid: false)
    expect(source_installment.cash_transaction).to have_attributes(month: 9, year: 2026, paid: false)
    expect(source_installment.cash_transaction.date.to_date).to eq(september.reference_date)
    expect(target_installment.reload).to have_attributes(date: Time.zone.local(2026, 9, 29), month: 10, year: 2026, paid: false)
    expect(target_installment.cash_transaction).to have_attributes(month: 10, year: 2026, paid: false)
  end

  it "moves each card-bound exchange bucket and resynchronizes distinct return projections" do
    august = create_reference(8, 2026)
    september = create_reference(9, 2026)
    [ august, september ].each { |reference| create_invoice(reference) }
    transaction = create_transaction_for([ august, september ])
    source_exchange, target_exchange = attach_card_bound_exchanges(transaction, [ august, september ])
    source_projection_id = source_exchange.cash_transaction_id

    result = described_class.new(plan: build_plan).call

    expect(result).to be_applied
    expect(source_exchange.reload).to have_attributes(month: 9, year: 2026)
    expect(source_exchange.date.to_date).to eq(september.reference_date)
    october_reference = user_card.references.find_by!(context:, month: 10, year: 2026)
    expect(target_exchange.reload).to have_attributes(month: 10, year: 2026)
    expect(target_exchange.date.to_date).to eq(october_reference.reference_date)
    expect(CashTransaction).not_to exist(source_projection_id)

    september_projection = context.cash_transactions.exchange_return.find_by!(user_card:, month: 9, year: 2026)
    october_projection = context.cash_transactions.exchange_return.find_by!(user_card:, month: 10, year: 2026)
    expect(september_projection).to have_attributes(price: 500)
    expect(september_projection.cash_installments.sole.price).to eq(500)
    expect(october_projection).to have_attributes(price: 1_000)
    expect(october_projection.cash_installments.sole.price).to eq(1_000)
  end

  it "rolls installment and exchange movements back together when projection synchronization fails" do
    august = create_reference(8, 2026)
    september = create_reference(9, 2026)
    [ august, september ].each { |reference| create_invoice(reference) }
    transaction = create_transaction_for([ august, september ])
    exchanges = attach_card_bound_exchanges(transaction, [ august, september ])
    original_installments = transaction.card_installments.order(:id).pluck(:id, :date, :month, :year, :cash_transaction_id)
    original_exchanges = exchanges.map { |exchange| exchange.reload.attributes.slice("id", "date", "month", "year", "cash_transaction_id") }
    allow_any_instance_of(Exchange).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(exchanges.first))

    result = described_class.new(plan: build_plan).call

    expect(result).to be_failed
    expect(transaction.card_installments.reload.order(:id).pluck(:id, :date, :month, :year, :cash_transaction_id)).to eq(original_installments)
    expect(exchanges.map { |exchange| exchange.reload.attributes.slice("id", "date", "month", "year", "cash_transaction_id") }).to eq(original_exchanges)
    expect(user_card.references).to exist(context:, month: 8, year: 2026)
  end

  it "rejects a stale plan when affected financial state changes before locking" do
    transaction, = create_year_transaction
    plan = build_plan
    transaction.card_installments.find_by!(number: 10).update_columns(price: -1_500)

    result = described_class.new(plan:).call

    expect(result).to be_rejected
    expect(result.reason_code).to eq("stale_plan")
    expect(user_card.references).to exist(context:, month: 8, year: 2026)
  end

  it "rolls the whole shift back when a downstream recalculation fails" do
    transaction, = create_year_transaction
    original_rows = transaction.card_installments.order(:number).pluck(:id, :date, :month, :year, :cash_transaction_id)
    original_reference_ids = user_card.references.where(context:).order(:year, :month).ids
    allow_any_instance_of(Logic::RecalculateBalancesService).to receive(:call).and_raise(ActiveRecord::RecordInvalid.new(transaction))
    expect(Rails.logger).to receive(:error).with(include("reference_reallocation_failed", '"reason_code":"apply_failed"'))

    result = described_class.new(plan: build_plan).call

    expect(result).to be_failed
    expect(transaction.card_installments.reload.order(:number).pluck(:id, :date, :month, :year, :cash_transaction_id)).to eq(original_rows)
    expect(user_card.references.where(context:).order(:year, :month).ids).to eq(original_reference_ids)
  end
end
