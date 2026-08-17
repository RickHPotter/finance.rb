# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit rollback for reference installment reallocation" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:, due_date_day: 12, days_until_due_date: 5) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:card_payment_category) { user.built_in_category("CARD PAYMENT") }
  let(:exchange_category) { user.built_in_category("EXCHANGE") }

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
      cash_installments: [
        build(
          :cash_installment,
          number: 1,
          date: reference.reference_date.end_of_day,
          month: reference.month,
          year: reference.year,
          price: -1_000,
          paid: false
        )
      ],
      category_transactions: [ CategoryTransaction.new(category: card_payment_category) ],
      entity_transactions: []
    )
  end

  def create_transaction(references)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: references.first.reference_closing_date - 1.day,
      month: references.first.month,
      year: references.first.year,
      price: -2_000,
      card_installments: references.map.with_index do |reference, index|
        build(
          :card_installment,
          number: index + 1,
          date: reference.reference_closing_date - 1.day,
          month: reference.month,
          year: reference.year,
          price: -1_000,
          paid: false
        )
      end,
      category_transactions: [],
      entity_transactions: []
    )
  end

  def setup_graph(with_exchanges: false)
    references = [ create_reference(8), create_reference(9) ]
    references.each { |reference| create_invoice(reference) }
    transaction = create_transaction(references)
    attach_exchanges(transaction, references) if with_exchanges
    transaction
  end

  def attach_exchanges(transaction, references)
    transaction.categories << exchange_category
    entity_transaction = create(
      :entity_transaction,
      transactable: transaction,
      entity: create(:entity, :random, user:),
      is_payer: true,
      price: transaction.price,
      price_to_be_returned: transaction.price.abs
    )
    references.each_with_index do |reference, index|
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
    entity_transaction.reload.save!
  end

  def snapshot
    card_transactions = context.card_transactions.where(user_card:).order(:id)
    cash_transactions = context.cash_transactions.where(user_card:).order(:id)
    card_transaction_ids = card_transactions.ids
    cash_transaction_ids = cash_transactions.ids
    entity_transactions = EntityTransaction.where(
      "(transactable_type = 'CardTransaction' AND transactable_id IN (?)) OR " \
      "(transactable_type = 'CashTransaction' AND transactable_id IN (?))",
      card_transaction_ids,
      cash_transaction_ids
    )
    category_transactions = CategoryTransaction.where(
      "(transactable_type = 'CardTransaction' AND transactable_id IN (?)) OR " \
      "(transactable_type = 'CashTransaction' AND transactable_id IN (?))",
      card_transaction_ids,
      cash_transaction_ids
    )

    serialize_records(
      Reference.where(context:, user_card:),
      card_transactions,
      cash_transactions,
      CardInstallment.unscoped.where(card_transaction_id: card_transaction_ids, installment_type: "CardInstallment"),
      CashInstallment.unscoped.where(cash_transaction_id: cash_transaction_ids, installment_type: "CashInstallment"),
      category_transactions,
      entity_transactions,
      Exchange.where(entity_transaction_id: entity_transactions.ids).or(Exchange.where(cash_transaction_id: cash_transaction_ids))
    )
  end

  def serialize_records(*relations)
    relations.flat_map(&:to_a).sort_by { |record| [ record.class.base_class.name, record.id ] }.map do |record|
      [
        record.class.base_class.name,
        record.id,
        Audit::Rollback::State.normalize(
          record.class.base_class.name,
          record.attributes.except("created_at", "updated_at", "balance", "order_id")
        )
      ]
    end
  end

  def apply_rollback(operation, preview)
    Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token
    ).call
  end

  def snapshot_differences(before_snapshot, after_snapshot)
    before_by_key = before_snapshot.to_h { |record_type, id, attributes| [ [ record_type, id ], attributes ] }
    after_by_key = after_snapshot.to_h { |record_type, id, attributes| [ [ record_type, id ], attributes ] }
    (before_by_key.keys | after_by_key.keys).sort.filter_map do |key|
      next if before_by_key[key] == after_by_key[key]

      before_attributes = before_by_key[key] || {}
      after_attributes = after_by_key[key] || {}
      changes = (before_attributes.keys | after_attributes.keys).sort.to_h do |attribute|
        [ attribute, [ before_attributes[attribute], after_attributes[attribute] ] ]
      end
      changes.reject! { |_attribute, values| values.first == values.last }
      [ key, changes ]
    end
  end

  def merge_operation
    expect(
      Logic::References.merge(
        user_card,
        "2026-08-01",
        "2026-09-01",
        merge_mode: Logic::References::REALLOCATE_INSTALLMENTS,
        context:
      )
    ).to be(true)
    AuditOperation.where("metadata ->> 'reference_merge_mode' = ?", Logic::References::REALLOCATE_INSTALLMENTS).order(:created_at).last
  end

  def expect_previewable(preview)
    unsupported_rows = preview.rows.filter_map do |row|
      next if row.support_issues.empty?

      [ row.record_type, row.item_id, row.action, row.support_issues.map(&:code) ]
    end
    expect(unsupported_rows).to be_empty
    expect(preview).to have_attributes(state: "previewable")
  end

  it "previews and restores the exact pre-merge financial graph" do
    setup_graph
    before_snapshot = snapshot
    operation = merge_operation
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect_previewable(preview)
    result = apply_rollback(operation, preview)

    expect(result).to have_attributes(status: "applied")
    expect(snapshot_differences(before_snapshot, snapshot)).to be_empty
    expect(result.operation).to have_attributes(source: "rollback", rollback_of_operation_id: operation.id)
  end

  it "restores card-bound exchanges and their return projections with the invoice graph" do
    setup_graph(with_exchanges: true)
    before_snapshot = snapshot
    operation = merge_operation
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect_previewable(preview)
    result = apply_rollback(operation, preview)

    expect(result).to have_attributes(status: "applied")
    expect(snapshot_differences(before_snapshot, snapshot)).to be_empty
  end

  it "conflicts instead of partially restoring an installment changed after the merge" do
    transaction = setup_graph
    operation = merge_operation
    transaction.card_installments.order(:number).last.update!(price: -1_500)

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    installment_conflicts = preview.rows.select { |row| row.record_type == "CardInstallment" }.flat_map(&:conflicts).map(&:code)
    expect(installment_conflicts).to include("current_state_changed")
  end
end
