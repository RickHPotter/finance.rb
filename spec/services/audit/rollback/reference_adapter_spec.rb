# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Reference do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:account) { create(:user_bank_account, :random, user:) }

  def apply(operation, confirmed: false)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed:
    ).call
    [ preview, result ]
  end

  def audited_operation
    operation = nil
    Audit::Operation.run(actor: user, context:, source: :web) do
      yield
      operation = Audit::Operation.ensure_persisted!
    end
    operation
  end

  def create_invoice(reference, price:)
    PaperTrail.request(enabled: false) do
      invoice = create_cash_invoice(reference, price:)
      card_transaction = create_invoice_card_transaction(reference, price:)
      card_transaction.card_installments.sole.update!(
        cash_transaction: invoice,
        month: reference.month,
        year: reference.year,
        price:
      )
      invoice.reload
    end
  end

  def create_cash_invoice(reference, price:)
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
      category_transactions: [
        CategoryTransaction.new(category: user.built_in_category("CARD PAYMENT"))
      ],
      entity_transactions: []
    )
  end

  def create_invoice_card_transaction(reference, price:)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      month: reference.month,
      year: reference.year,
      price:,
      category_transactions: [],
      entity_transactions: []
    )
  end

  it "restores an ordinary billing reference update exactly" do
    reference = PaperTrail.request(enabled: false) { create(:reference, user_card:, context:) }
    original_date = reference.reference_date
    original_closing_date = reference.reference_closing_date
    operation = audited_operation { reference.update!(reference_date: original_date + 2.days) }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(reference.reload).to have_attributes(reference_date: original_date, reference_closing_date: original_closing_date)
  end

  it "recreates a destroyed reference without resynchronizing an unrelated invoice" do
    reference = PaperTrail.request(enabled: false) { create(:reference, user_card:, context:) }
    reference_id = reference.id
    operation = audited_operation { reference.destroy! }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Reference.find(reference_id)).to have_attributes(user_card_id: user_card.id, context_id: context.id)
  end

  it "reports occupied month/year or reference-date keys before apply" do
    reference = PaperTrail.request(enabled: false) { create(:reference, user_card:, context:) }
    operation = audited_operation { reference.destroy! }
    PaperTrail.request(enabled: false) do
      create(
        :reference,
        user_card:,
        context:,
        month: reference.month,
        year: reference.year,
        reference_date: reference.reference_date,
        reference_closing_date: reference.reference_closing_date
      )
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.sole.conflicts.map(&:code)).to include("reference_key_taken")
  end

  it "restores a reference edit and its generated unpaid-invoice dates atomically" do
    reference = PaperTrail.request(enabled: false) { create(:reference, user_card:, context:) }
    invoice = create_invoice(reference, price: -1_000)
    original_invoice_date = invoice.date
    original_installment_date = invoice.cash_installments.sole.date
    operation = audited_operation { reference.update!(reference_date: reference.reference_date + 3.days) }

    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_subtype)).to include("Reference", "CashTransaction", "CashInstallment")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(invoice.reload.date.iso8601(3)).to eq(original_invoice_date.iso8601(3))
    expect(invoice.cash_installments.sole.reload.date.iso8601(3)).to eq(original_installment_date.iso8601(3))
  end

  it "restores a UserCard payment-date change and its replacement reference graph" do
    user_card.update_columns(due_date_day: 9, days_until_due_date: 7)
    references = PaperTrail.request(enabled: false) do
      [ 11, 12 ].map do |month|
        create(
          :reference,
          user_card:,
          context:,
          month:,
          year: 2026,
          reference_date: Date.new(2026, month, 9),
          reference_closing_date: Date.new(2026, month, 2)
        )
      end
    end
    references.first.update_columns(reference_closing_date: Date.new(2026, 10, 2))
    invoices = references.map { |reference| create_invoice(reference, price: -1_000) }
    original_reference_ids = references.map(&:id)
    original_invoice_dates = invoices.to_h { |invoice| [ invoice.id, invoice.date.iso8601(3) ] }
    original_installment_dates = invoices.to_h { |invoice| [ invoice.id, invoice.cash_installments.sole.date.iso8601(3) ] }

    operation = audited_operation do
      user_card.update!(
        due_date_day: 8,
        days_until_due_date: 37,
        current_due_date: Date.new(2026, 11, 8),
        current_closing_date: Date.new(2026, 10, 2)
      )
    end

    expect(Reference.where(id: original_reference_ids)).to be_empty
    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_subtype)).to include("UserCard", "Reference", "CashTransaction", "CashInstallment")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(user_card.reload).to have_attributes(due_date_day: 9, days_until_due_date: 7)
    expect(Reference.where(id: original_reference_ids).order(:month).pluck(:month, :reference_date, :reference_closing_date)).to eq(
      [ [ 11, Date.new(2026, 11, 9), Date.new(2026, 10, 2) ], [ 12, Date.new(2026, 12, 9), Date.new(2026, 12, 2) ] ]
    )
    invoices.each do |invoice|
      expect(invoice.reload.date.iso8601(3)).to eq(original_invoice_dates.fetch(invoice.id))
      expect(invoice.cash_installments.sole.reload.date.iso8601(3)).to eq(original_installment_dates.fetch(invoice.id))
    end
  end

  it "restores a neighboring reference merge and its invoice routing graph" do
    march_reference = PaperTrail.request(enabled: false) do
      create(
        :reference,
        user_card:,
        context:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 12),
        reference_closing_date: Date.new(2026, 3, 5)
      )
    end
    april_reference = PaperTrail.request(enabled: false) do
      create(
        :reference,
        user_card:,
        context:,
        month: 4,
        year: 2026,
        reference_date: Date.new(2026, 4, 12),
        reference_closing_date: Date.new(2026, 4, 5)
      )
    end
    original_april_closing_date = april_reference.reference_closing_date
    march_invoice = create_invoice(march_reference, price: -1_000)
    april_invoice = create_invoice(april_reference, price: -1_200)
    merge_result = Logic::References.merge_result(
      user_card,
      "2026-03-01",
      "2026-04-01",
      merge_mode: Logic::References::COMBINE_INTO_TARGET,
      context:
    )
    expect(merge_result).to be_applied
    operation = merge_result.operation

    preview, result = apply(operation)
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Reference).to exist(march_reference.id)
    expect(april_reference.reload.reference_closing_date).to eq(original_april_closing_date)
    expect(CashTransaction).to exist(march_invoice.id)
    expect(CashTransaction).to exist(april_invoice.id)
  end

  it "restores a confirmed merge of paid card-bound exchange projections" do
    entity = create(:entity, :random, user:)
    august_reference = create(
      :reference,
      user_card:,
      context:,
      month: 8,
      year: 2026,
      reference_date: Date.new(2026, 8, 12),
      reference_closing_date: Date.new(2026, 8, 5)
    )
    september_reference = create(
      :reference,
      user_card:,
      context:,
      month: 9,
      year: 2026,
      reference_date: Date.new(2026, 9, 12),
      reference_closing_date: Date.new(2026, 9, 5)
    )
    august_invoice = create_invoice(august_reference, price: -1_000)
    september_invoice = create_invoice(september_reference, price: -1_000)
    card_transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      month: 8,
      year: 2026,
      price: -2_000,
      card_installments: [
        build(:card_installment, number: 1, month: 8, year: 2026, price: -1_000),
        build(:card_installment, number: 2, month: 9, year: 2026, price: -1_000)
      ],
      entity_transactions: [
        build(:entity_transaction, entity:, transactable: nil, is_payer: false, price: 0, price_to_be_returned: 0)
      ]
    )
    card_transaction.card_installments.find_by!(number: 1).update_columns(cash_transaction_id: august_invoice.id)
    card_transaction.card_installments.find_by!(number: 2).update_columns(cash_transaction_id: september_invoice.id)
    source_exchange = create_paid_card_bound_exchange(card_transaction:, entity:, reference: august_reference)
    target_exchange = create_paid_card_bound_exchange(card_transaction:, entity:, reference: september_reference)
    source_projection = source_exchange.cash_transaction
    target_projection = target_exchange.cash_transaction
    source_paid_installment = source_projection.cash_installments.sole
    target_paid_installment = target_projection.cash_installments.sole

    result = Logic::References.merge_result(
      user_card,
      august_reference.reference_date,
      september_reference.reference_date,
      merge_mode: Logic::References::COMBINE_INTO_TARGET,
      context:,
      historical_correction_confirmation: true
    )
    preview, rollback = apply(result.operation, confirmed: true)

    expect(preview).to have_attributes(state: "previewable")
    expect(rollback).to have_attributes(status: "applied")
    expect(Reference).to exist(august_reference.id)
    expect(CashTransaction).to exist(source_projection.id)
    expect(source_exchange.reload).to have_attributes(month: 8, year: 2026, cash_transaction_id: source_projection.id)
    expect(target_exchange.reload).to have_attributes(month: 9, year: 2026, cash_transaction_id: target_projection.id)
    expect(source_paid_installment.reload).to have_attributes(price: 1_000, paid: true, cash_transaction_id: source_projection.id)
    expect(target_paid_installment.reload).to have_attributes(price: 1_000, paid: true, cash_transaction_id: target_projection.id)
  end

  def create_paid_card_bound_exchange(card_transaction:, entity:, reference:)
    exchange = create(
      :exchange,
      entity_transaction: card_transaction.entity_transactions.find_by!(entity:),
      exchange_type: :monetary,
      bound_type: :card_bound,
      month: reference.month,
      year: reference.year,
      date: reference.reference_date,
      price: 1_000
    )
    exchange.cash_transaction.cash_installments.sole.update_columns(paid: true)
    exchange.cash_transaction.update_columns(paid: true)
    exchange
  end
end
