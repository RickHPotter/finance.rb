# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Reference do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:account) { create(:user_bank_account, :random, user:) }

  def apply(operation)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token
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
    expect(Logic::References.merge(user_card, "2026-03-01", "2026-04-01", context:)).to be_truthy
    operation = AuditOperation.last

    preview, result = apply(operation)
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Reference).to exist(march_reference.id)
    expect(april_reference.reload.reference_closing_date).to eq(original_april_closing_date)
    expect(CashTransaction).to exist(march_invoice.id)
    expect(CashTransaction).to exist(april_invoice.id)
  end
end
