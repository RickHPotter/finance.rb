# frozen_string_literal: true

class Audit::Rollback::Recalculator
  attr_reader :impact

  def initialize(impact:)
    @impact = impact
  end

  def call
    recalculate_cash_transactions
    recalculate_card_transactions
    recalculate_routing_totals
    recalculate_allocation_totals
    recalculate_balances
  end

  private

  def recalculate_cash_transactions
    CashTransaction.unscoped.where(id: impact.cash_transaction_ids).find_each do |transaction|
      count = transaction.cash_installments.count
      paid = count.positive? && transaction.cash_installments.where(paid: false).none?
      Audit::BulkMutation.update_columns!(transaction, cash_installments_count: count, paid:)
      Audit::BulkMutation.update_all!(transaction.cash_installments, cash_installments_count: count)
    end
  end

  def recalculate_card_transactions
    CardTransaction.unscoped.where(id: impact.card_transaction_ids).find_each do |transaction|
      count = transaction.card_installments.count
      paid = count.positive? && transaction.card_installments.where(paid: false).none?
      Audit::BulkMutation.update_columns!(transaction, card_installments_count: count, paid:)
      Audit::BulkMutation.update_all!(transaction.card_installments, card_installments_count: count)
    end
  end

  def recalculate_routing_totals
    UserBankAccount.where(id: impact.user_bank_account_ids).find_each do |account|
      Audit::BulkMutation.update_columns!(
        account,
        cash_transactions_count: account.cash_transactions.count,
        cash_transactions_total: account.cash_transactions.sum(:price)
      )
    end
    UserCard.where(id: impact.user_card_ids).find_each do |card|
      Audit::BulkMutation.update_columns!(
        card,
        card_transactions_count: card.card_transactions.count,
        card_transactions_total: card.card_transactions.sum(:price)
      )
    end
  end

  def recalculate_allocation_totals
    Category.where(id: impact.cash_category_ids).find_each(&:update_cash_transactions_count_and_total)
    Category.where(id: impact.card_category_ids).find_each(&:update_card_transactions_count_and_total)
    Entity.where(id: impact.cash_entity_ids).find_each(&:update_cash_transactions_count_and_total)
    Entity.where(id: impact.card_entity_ids).find_each(&:update_card_transactions_count_and_total)
  end

  def recalculate_balances
    impact.owner_contexts.sort.each do |owner_id, context_id|
      context = Context.find_by(id: context_id, user_id: owner_id)
      next unless context

      date = impact.earliest_dates[context_id]
      Logic::RecalculateBalancesService.new(user: context.user, context:, year: date&.year, month: date&.month).call
    end
  end
end
