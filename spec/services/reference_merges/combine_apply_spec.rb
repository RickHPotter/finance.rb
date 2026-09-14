# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceMerges::CombineApply do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:account) { create(:user_bank_account, :random, user:) }

  subject(:service) do
    described_class.new(
      user_card:,
      context:,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    )
  end

  it "rejects a missing canonical graph without audit history" do
    service
    result = nil

    expect { result = service.call }.not_to change(AuditOperation, :count)

    expect(result).to have_attributes(status: "rejected", reason_code: "combine_missing_root", operation: nil)
  end

  it "rejects a context owned by another user before mutation" do
    foreign_context = create(:user, :different).main_context
    result = described_class.new(
      user_card:,
      context: foreign_context,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    ).call

    expect(result).to have_attributes(status: "rejected", reason_code: "context_mismatch", operation: nil)
  end

  it "acquires the shared user-card/context advisory lock with a safely quoted key" do
    expect do
      ApplicationRecord.transaction { ReferenceMerges::Lock.acquire!(user_card:, context:) }
    end.not_to raise_error
  end

  it "rejects paid source exchange-return history before mutating the combine graph" do
    source_reference = create_reference(8)
    target_reference = create_reference(9)
    source_invoice = create_invoice(source_reference)
    target_invoice = create_invoice(target_reference)
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
      ]
    )
    card_transaction.card_installments.find_by!(number: 1).update_columns(cash_transaction_id: source_invoice.id)
    card_transaction.card_installments.find_by!(number: 2).update_columns(cash_transaction_id: target_invoice.id)
    exchange = create(
      :exchange,
      entity_transaction: card_transaction.entity_transactions.first,
      exchange_type: :monetary,
      bound_type: :card_bound,
      month: 8,
      year: 2026,
      date: source_reference.reference_date,
      price: 1_000
    )
    projection = exchange.cash_transaction
    projection.cash_installments.sole.update_columns(paid: true)
    projection.update_columns(paid: true)
    original_graph = [ source_reference, target_reference, source_invoice, target_invoice, exchange, projection ].to_h do |record|
      [ [ record.class.base_class.name, record.id ], record.reload.attributes ]
    end

    result = service.call

    expect(result).to have_attributes(status: "rejected", reason_code: "locked_exchange_history", operation: nil)
    expect(AuditOperation.where("metadata ->> 'reference_merge_mode' = ?", Logic::References::COMBINE_INTO_TARGET)).to be_empty
    original_graph.each do |(record_type, record_id), attributes|
      expect(record_type.constantize.find(record_id).attributes).to eq(attributes)
    end
  end

  def create_reference(month)
    create(
      :reference,
      user_card:,
      context:,
      month:,
      year: 2026,
      reference_date: Date.new(2026, month, 12),
      reference_closing_date: Date.new(2026, month, 7)
    )
  end

  def create_invoice(reference)
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
      price: -1_000,
      paid: false,
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("CARD PAYMENT")) ],
      entity_transactions: []
    )
  end
end
