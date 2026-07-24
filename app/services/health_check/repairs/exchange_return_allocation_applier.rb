# frozen_string_literal: true

class HealthCheck::Repairs::ExchangeReturnAllocationApplier
  attr_reader :preview, :scope

  def initialize(scope:, preview:)
    @scope = scope
    @preview = preview
  end

  def call
    entity_transaction = EntityTransaction.includes(:transactable).find(preview.finding_id)
    transactable = entity_transaction.transactable
    raise ActiveRecord::RecordNotFound unless transactable.respond_to?(:context_id) && transactable.context_id == scope.context.id

    Logic::ExchangeReturnAllocationRepair.new(
      entity_transaction:,
      attributes: preview.changes.index_with(&:after).transform_keys(&:attribute)
    ).call
    recalculate_from(transactable)
  end

  private

  def recalculate_from(transactable)
    return unless transactable.respond_to?(:date) && transactable.date.present?

    Logic::RecalculateBalancesService.new(
      user: scope.user,
      context: scope.context,
      year: transactable.date.year,
      month: transactable.date.month
    ).call
  end
end
