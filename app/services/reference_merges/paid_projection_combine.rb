# frozen_string_literal: true

class ReferenceMerges::PaidProjectionCombine
  attr_reader :source_exchanges, :destination_exchanges, :target_reference

  def initialize(source_exchanges:, destination_exchanges:, target_reference:)
    @source_exchanges = source_exchanges
    @destination_exchanges = destination_exchanges
    @target_reference = target_reference
  end

  def paid_history?
    projections.any?(&:paid_history?)
  end

  def supported?
    source_projections.one? &&
      destination_projections.size <= 1 &&
      paid_price <= combined_price &&
      projections.all? { |projection| valid_projection?(projection) } &&
      projections.flat_map(&:exchange_ids).sort == all_exchanges.map(&:id).sort
  end

  def call
    raise ArgumentError, "Unsupported paid exchange-return projection graph" unless supported?

    move_exchanges!
    reconcile_installments!
    update_projection!
    delete_redundant_projections!
    synchronize_entity_statuses!
  end

  private

  def source_projections
    @source_projections ||= source_exchanges.filter_map(&:cash_transaction).uniq(&:id)
  end

  def destination_projections
    @destination_projections ||= destination_exchanges.filter_map(&:cash_transaction).uniq(&:id)
  end

  def projections
    @projections ||= [ *source_projections, *destination_projections ].uniq(&:id)
  end

  def canonical_projection
    @canonical_projection ||= destination_projections.first || source_projections.sole
  end

  def all_exchanges
    @all_exchanges ||= [ *source_exchanges, *destination_exchanges ].uniq(&:id)
  end

  def installments
    @installments ||= projections.flat_map { |projection| projection.cash_installments.to_a }.uniq(&:id)
  end

  def paid_installments
    @paid_installments ||= installments.select(&:paid?).sort_by { |installment| [ installment.date, installment.id ] }
  end

  def unpaid_installments
    @unpaid_installments ||= installments.reject(&:paid?)
  end

  def combined_price
    @combined_price ||= all_exchanges.sum(&:price)
  end

  def paid_price
    @paid_price ||= paid_installments.sum(&:price)
  end

  def remaining_price
    combined_price - paid_price
  end

  def valid_projection?(projection)
    projection.user_id == target_reference.user_card.user_id &&
      projection.context_id == target_reference.context_id &&
      projection.user_card_id == target_reference.user_card_id &&
      projection.price == projection.exchanges.sum(:price) &&
      projection.price == projection.cash_installments.sum(:price)
  end

  def projection_date
    target_reference.reference_date.end_of_day
  end

  def exchange_date
    target_reference.reference_date.in_time_zone
  end

  def move_exchanges!
    all_exchanges.each do |exchange|
      attributes = { cash_transaction_id: canonical_projection.id }
      attributes.merge!(month: target_reference.month, year: target_reference.year, date: exchange_date) if source_exchanges.include?(exchange)
      Audit::BulkMutation.update_columns!(exchange, attributes)
    end
  end

  def reconcile_installments!
    total_count = paid_installments.size + (remaining_price.positive? ? 1 : 0)

    paid_installments.each_with_index do |installment, index|
      Audit::BulkMutation.update_columns!(
        installment,
        cash_transaction_id: canonical_projection.id,
        number: index + 1,
        cash_installments_count: total_count
      )
    end

    reconcile_unpaid_installment!(total_count)
  end

  def reconcile_unpaid_installment!(total_count)
    retained = preferred_unpaid_installment
    delete_discarded_unpaid_installments!(retained)

    if remaining_price.zero?
      Audit::BulkMutation.delete_all!(CashInstallment.where(id: retained.id)) if retained
      return
    end

    retained ||= create_unpaid_installment!(total_count)

    Audit::BulkMutation.update_columns!(retained, unpaid_installment_attributes(total_count))
  end

  def delete_discarded_unpaid_installments!(retained)
    discarded_ids = unpaid_installments.reject { |installment| installment == retained }.map(&:id)
    Audit::BulkMutation.delete_all!(CashInstallment.where(id: discarded_ids)) if discarded_ids.present?
  end

  def create_unpaid_installment!(total_count)
    canonical_projection.cash_installments.create!(
      number: total_count,
      date: projection_date,
      month: target_reference.month,
      year: target_reference.year,
      price: remaining_price,
      starting_price: remaining_price,
      paid: false,
      cash_installments_count: total_count
    )
  end

  def unpaid_installment_attributes(total_count)
    {
      cash_transaction_id: canonical_projection.id,
      number: total_count,
      date: projection_date,
      month: target_reference.month,
      year: target_reference.year,
      price: remaining_price,
      starting_price: remaining_price,
      paid: false,
      cash_installments_count: total_count
    }
  end

  def preferred_unpaid_installment
    canonical_unpaid = unpaid_installments.select { |installment| installment.cash_transaction_id == canonical_projection.id }
    (canonical_unpaid.presence || unpaid_installments).min_by(&:id)
  end

  def update_projection!
    sample_exchange = source_exchanges.first
    Audit::BulkMutation.update_columns!(
      canonical_projection,
      description: sample_exchange.send(:projection_description),
      starting_price: combined_price,
      price: combined_price,
      date: projection_date,
      month: target_reference.month,
      year: target_reference.year,
      paid: remaining_price.zero?,
      cash_installments_count: paid_installments.size + (remaining_price.positive? ? 1 : 0)
    )
  end

  def delete_redundant_projections!
    redundant_ids = projections.reject { |projection| projection == canonical_projection }.map(&:id)
    return if redundant_ids.empty?

    Audit::BulkMutation.delete_all!(CategoryTransaction.where(transactable_type: "CashTransaction", transactable_id: redundant_ids))
    Audit::BulkMutation.delete_all!(EntityTransaction.where(transactable_type: "CashTransaction", transactable_id: redundant_ids))
    Audit::BulkMutation.delete_all!(CashTransaction.where(id: redundant_ids))
  end

  def synchronize_entity_statuses!
    all_exchanges.map(&:entity_transaction).uniq(&:id).each do |entity_transaction|
      exchanges = entity_transaction.exchanges.reload
      finished = exchanges.all? { |exchange| exchange.non_monetary? || exchange.cash_transaction&.paid? }
      Audit::BulkMutation.update_columns!(entity_transaction, status: finished ? "finished" : "pending")
    end
  end
end
