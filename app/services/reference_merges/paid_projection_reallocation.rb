# frozen_string_literal: true

class ReferenceMerges::PaidProjectionReallocation
  attr_reader :projection, :exchanges, :destination_reference

  def initialize(projection:, exchanges:, destination_reference: nil)
    @projection = projection
    @exchanges = exchanges
    @destination_reference = destination_reference
  end

  def supported?
    exchanges.present? &&
      projection.price == exchanges.sum(&:price) &&
      projection.price == projection.cash_installments.sum(:price) &&
      projection.exchange_ids.sort == exchanges.map(&:id).sort &&
      exchanges.map { |exchange| [ exchange.month, exchange.year ] }.uniq.one?
  end

  def call
    raise ArgumentError, "Unsupported paid exchange-return projection graph" unless supported? && destination_reference

    move_exchanges!
    move_unpaid_installments!
    move_projection!
  end

  private

  def exchange_date
    destination_reference.reference_date.in_time_zone
  end

  def projection_date
    destination_reference.reference_date.end_of_day
  end

  def move_exchanges!
    exchanges.each do |exchange|
      Audit::BulkMutation.update_columns!(
        exchange,
        date: exchange_date,
        month: destination_reference.month,
        year: destination_reference.year
      )
    end
  end

  def move_unpaid_installments!
    projection.cash_installments.where(paid: false).find_each do |installment|
      Audit::BulkMutation.update_columns!(
        installment,
        date: projection_date,
        month: destination_reference.month,
        year: destination_reference.year
      )
    end
  end

  def move_projection!
    Audit::BulkMutation.update_columns!(
      projection,
      description: exchanges.first.send(:projection_description),
      date: projection_date,
      month: destination_reference.month,
      year: destination_reference.year
    )
  end
end
