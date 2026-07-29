# frozen_string_literal: true

class AllocationMutations::ImpactRecalculator
  attr_reader :actor, :context, :impacts

  def initialize(actor:, context:, impacts:)
    @actor = actor
    @context = context
    @impacts = Array(impacts).freeze
  end

  def call
    recalculate_allocation_totals
    recalculate_affected_budgets
    recalculate_budget_balances
  end

  private

  def recalculate_allocation_totals
    Category.where(id: category_ids("CashTransaction")).find_each(&:update_cash_transactions_count_and_total)
    Category.where(id: category_ids("CardTransaction")).find_each(&:update_card_transactions_count_and_total)
    Entity.where(id: entity_ids("CashTransaction")).find_each(&:update_cash_transactions_count_and_total)
    Entity.where(id: entity_ids("CardTransaction")).find_each(&:update_card_transactions_count_and_total)
  end

  def recalculate_affected_budgets
    transaction_impacts = impacts.select { |impact| impact.owner_type.in?(%w[CashTransaction CardTransaction]) }
    return if transaction_impacts.empty?

    reference_months = transaction_impacts.flat_map(&:reference_months).uniq
    return if reference_months.empty?

    scope = context.budgets.where(reference_month_conditions(reference_months))

    context.budgets.where(id: affected_budget_ids(scope, transaction_impacts)).find_each do |budget|
      budget.recalculate_balance = false
      budget.save!
    end
  end

  def affected_budget_ids(scope, transaction_impacts)
    category_ids = transaction_impacts.select(&:category_changed?).flat_map(&:affected_category_ids).uniq
    entity_ids = transaction_impacts.select(&:entity_changed?).flat_map(&:affected_entity_ids).uniq
    [].tap do |budget_ids|
      budget_ids.concat(scope.joins(:budget_categories).where(budget_categories: { category_id: category_ids }).ids) if category_ids.any?
      budget_ids.concat(scope.joins(:budget_entities).where(budget_entities: { entity_id: entity_ids }).ids) if entity_ids.any?
    end.uniq
  end

  def recalculate_budget_balances
    dates = impacts
            .select { |impact| impact.owner_type == "Budget" && impact.balance_recalculation_required }
            .flat_map(&:reference_months)
    return if dates.empty?

    earliest = dates.min
    Logic::RecalculateBalancesService.new(user: actor, context:, year: earliest.year, month: earliest.month).call
  end

  def category_ids(owner_type)
    impacts.select { |impact| impact.owner_type == owner_type && impact.category_changed? }.flat_map(&:affected_category_ids).uniq
  end

  def entity_ids(owner_type)
    impacts.select { |impact| impact.owner_type == owner_type && impact.entity_changed? }.flat_map(&:affected_entity_ids).uniq
  end

  def reference_month_conditions(reference_months)
    reference_months
      .map { |date| { year: date.year, month: date.month } }
      .map { |attributes| Budget.arel_table[:year].eq(attributes[:year]).and(Budget.arel_table[:month].eq(attributes[:month])) }
      .reduce(&:or)
  end
end
