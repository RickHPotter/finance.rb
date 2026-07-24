# frozen_string_literal: true

class HealthCheck::Repairs::CardExchangeProjectionApplier
  attr_reader :preview, :scope

  def initialize(scope:, preview:)
    @scope = scope
    @preview = preview
  end

  def call
    target_id = target_reference&.fetch("id", nil)
    target_id ||= Array(target_reference&.fetch("ids", [])).sole
    target = scope.context.cash_transactions.find(target_id)
    earliest_date = target.date
    repair = Logic::CardExchangeProjectionRepair.new(
      current_user: scope.user,
      current_context: scope.context,
      cash_transaction: target
    )
    raise HealthCheck::Repairs::Apply::MutationError unless repair.fixable?

    repaired = repair.call
    recalculate_from([ earliest_date, repaired.date ].compact.min)
    repaired
  end

  private

  def target_reference
    preview.references.find { |reference| reference["role"] == "projection_target" }
  end

  def recalculate_from(date)
    Logic::RecalculateBalancesService.new(
      user: scope.user,
      context: scope.context,
      year: date.year,
      month: date.month
    ).call
  end
end
