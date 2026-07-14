# frozen_string_literal: true

class Logic::PiggyBankAudit
  attr_reader :audit_context, :current_user

  def initialize(current_user:, current_context: nil)
    @current_user = current_user
    @audit_context = current_context || current_user.ensure_main_context!
  end

  def call
    return_rows + missing_return_rows
  end

  private

  def return_rows
    audit_context.cash_transactions
                 .piggy_bank_return
                 .includes(:categories, :cash_installments, :entities, :piggy_bank_investments,
                           piggy_bank_return_links: { source_cash_transaction: %i[cash_installments entities categories] })
                 .filter_map { |transaction| audit_return(transaction) }
  end

  def audit_return(transaction)
    links = transaction.piggy_bank_return_links
    principal = links.sum(&:return_price)
    valuation_delta = transaction.piggy_bank_investments.sum(&:price)
    expected_total = principal + valuation_delta
    installments_total = transaction.cash_installments.sum(&:price)
    issues = return_issues(transaction, links:, expected_total:, installments_total:, valuation_delta:)
    return if issues.empty?

    {
      id: transaction.id,
      description: transaction.description,
      date: transaction.date,
      context: audit_context.name,
      principal:,
      valuation_delta:,
      expected_total:,
      recorded_total: transaction.price,
      installments_total:,
      issues:
    }
  end

  def return_issues(transaction, links:, expected_total:, installments_total:, valuation_delta:)
    issues = []
    append_relationship_issues(issues, transaction, links)
    append_projection_issues(issues, transaction, expected_total:, installments_total:, valuation_delta:)
    issues
  end

  def append_relationship_issues(issues, transaction, links)
    issues << "wrong_category" unless transaction.categories.any? { |category| category.category_name == "PIGGY BANK RETURN" }
    issues << "missing_contributions" if links.empty?
    issues << "user_context_mismatch" if links.any? { |link| source_scope_mismatch?(link.source_cash_transaction, transaction) }
    issues << "entity_mismatch" if links.any? { |link| source_entity_id(link.source_cash_transaction) != return_entity_id(transaction) }
    issues << "duplicate_contribution_ownership" if duplicate_source_ids.intersect?(links.map(&:source_cash_transaction_id))
    issues << "incompatible_sources" if incompatible_sources?(links, transaction)
  end

  def append_projection_issues(issues, transaction, expected_total:, installments_total:, valuation_delta:)
    total_drift = transaction.price != expected_total
    issues << "grouped_principal_drift" if total_drift
    issues << "valuation_profit_drift" if valuation_delta.nonzero? && total_drift
    issues << "source_return_amount_drift" if transaction.cash_installments.none?(&:paid?) && installments_total != expected_total
    issues << "illegal_installment_collapse" if partial_history_drift?(transaction, expected_total:)
  end

  def missing_return_rows
    PiggyBank.joins(:source_cash_transaction)
             .where(cash_transactions: { context_id: audit_context.id, user_id: current_user.id })
             .where(return_cash_transaction_id: nil)
             .map do |link|
      {
        id: nil,
        piggy_bank_id: link.id,
        description: link.source_cash_transaction.description,
        date: link.return_date,
        context: audit_context.name,
        principal: link.return_price,
        valuation_delta: 0,
        expected_total: link.return_price,
        recorded_total: nil,
        installments_total: nil,
        issues: [ "missing_return" ]
      }
    end
  end

  def source_scope_mismatch?(source, transaction)
    source.blank? || source.user_id != transaction.user_id || source.context_id != transaction.context_id
  end

  def incompatible_sources?(links, transaction)
    links.any? do |link|
      source = link.source_cash_transaction
      source.blank? || !source.piggy_bank_source? || source_scope_mismatch?(source, transaction)
    end
  end

  def partial_history_drift?(transaction, expected_total:)
    paid_total = transaction.cash_installments.select(&:paid?).sum(&:price)
    return false if paid_total.zero?

    unpaid = transaction.cash_installments.reject(&:paid?)
    expected_remaining = expected_total - paid_total
    expected_remaining.positive? ? unpaid.sum(&:price) != expected_remaining : unpaid.present?
  end

  def source_entity_id(source)
    return if source.blank?

    source.entity_transactions.reject(&:marked_for_destruction?).first&.entity_id
  end

  def return_entity_id(transaction)
    transaction.entity_transactions.first&.entity_id
  end

  def duplicate_source_ids
    @duplicate_source_ids ||= PiggyBank.group(:source_cash_transaction_id).having("COUNT(*) > 1").pluck(:source_cash_transaction_id)
  end
end
