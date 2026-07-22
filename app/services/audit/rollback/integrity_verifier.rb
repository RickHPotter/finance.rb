# frozen_string_literal: true

class Audit::Rollback::IntegrityVerifier
  class IntegrityError < StandardError; end

  attr_reader :preview, :impact

  def initialize(preview:, impact:)
    @preview = preview
    @impact = impact
  end

  def call
    preview.rows.each { |row| verify_row(row) }
    verify_transaction_counts
    verify_routing_totals
    true
  end

  private

  def verify_row(row)
    record = find_record(row)
    if row.before_state.nil?
      raise IntegrityError, "#{row.key} still exists after compensation" if record

      return
    end
    raise IntegrityError, "#{row.key} is missing after compensation" unless record

    expected = Audit::Rollback::Attributes.comparable_for(row)
    current = Audit::Rollback::State.normalize(row.record_type, record.attributes.slice(*expected.keys))
    raise IntegrityError, "#{row.key} does not match its restored state" unless current == expected

    ownership = Audit::OwnershipResolver.resolve!(record)
    return if ownership.owner_id == row.owner_id && ownership.context_id == row.context_id

    raise IntegrityError, "#{row.key} ownership changed during compensation"
  end

  def find_record(row)
    if row.record_type.in?(%w[CashInstallment CardInstallment])
      row.record_type.constantize.unscoped.find_by(id: row.item_id, installment_type: row.record_type)
    else
      row.record_type.constantize.unscoped.find_by(id: row.item_id)
    end
  end

  def verify_transaction_counts
    CashTransaction.unscoped.where(id: impact.cash_transaction_ids).find_each do |transaction|
      verify_installment_count(transaction, :cash_installments, :cash_installments_count)
    end
    CardTransaction.unscoped.where(id: impact.card_transaction_ids).find_each do |transaction|
      verify_installment_count(transaction, :card_installments, :card_installments_count)
    end
  end

  def verify_installment_count(transaction, association, count_attribute)
    installments = transaction.public_send(association)
    count = installments.count
    raise IntegrityError, "#{transaction.class.name} ##{transaction.id} has no installments" unless count.positive?
    raise IntegrityError, "#{transaction.class.name} ##{transaction.id} count cache is stale" unless transaction.public_send(count_attribute) == count
    raise IntegrityError, "#{transaction.class.name} ##{transaction.id} installment counts are stale" unless installments.where.not(count_attribute => count).none?

    expected_paid = installments.where(paid: false).none?
    raise IntegrityError, "#{transaction.class.name} ##{transaction.id} paid state is stale" unless transaction.paid? == expected_paid
  end

  def verify_routing_totals
    UserBankAccount.where(id: impact.user_bank_account_ids).find_each do |account|
      verify_cache(account, :cash_transactions, :cash_transactions_count, :cash_transactions_total)
    end
    UserCard.where(id: impact.user_card_ids).find_each do |card|
      verify_cache(card, :card_transactions, :card_transactions_count, :card_transactions_total)
    end
  end

  def verify_cache(record, association, count_attribute, total_attribute)
    scope = record.public_send(association)
    return if record.public_send(count_attribute) == scope.count && record.public_send(total_attribute) == scope.sum(:price)

    raise IntegrityError, "#{record.class.name} ##{record.id} totals are stale"
  end
end
