# frozen_string_literal: true

class ReferenceMerges::ReallocationApply
  class StalePlanError < StandardError; end
  class IntegrityError < StandardError; end

  Result = Data.define(:status, :reason_code, :plan, :operation) do
    def applied?
      status == "applied"
    end

    def rejected?
      status == "rejected"
    end

    def failed?
      status == "failed"
    end
  end

  attr_reader :plan

  def initialize(plan:)
    @plan = plan
  end

  def call
    unless plan.eligible?
      log_rejection(:ineligible_plan, issues: plan.issues.map { |issue| { code: issue.code, details: issue.details } })
      return result(:rejected, :ineligible_plan)
    end

    apply_inside_audit_operation
    result(:applied, operation: @operation)
  rescue StalePlanError, ActiveRecord::RecordNotFound => e
    log_rejection(:stale_plan, error: e)
    result(:rejected, :stale_plan)
  rescue ActiveRecord::ActiveRecordError, IntegrityError => e
    log_failure(e)
    result(:failed, :apply_failed)
  end

  private

  def apply_inside_audit_operation
    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor: plan.user_card.user,
      context: plan.context,
      metadata: operation_metadata
    ) do
      ApplicationRecord.transaction do
        lock_plan_records!
        @locked_plan = replan
        raise StalePlanError unless @locked_plan.eligible? && @locked_plan.digest == plan.digest

        apply_locked_plan!
        @operation = Audit::Operation.ensure_persisted!
      end
    end
  end

  def operation_metadata
    {
      reference_merge_mode: Logic::References::REALLOCATE_INSTALLMENTS,
      user_card_id: plan.user_card.id,
      context_id: plan.context.id,
      source_reference: plan.source_date.iso8601,
      target_reference: plan.target_date.iso8601,
      earliest_affected_reference: plan.earliest_affected_date&.iso8601,
      latest_affected_reference: plan.latest_affected_date&.iso8601,
      tail_reference: plan.tail_date&.iso8601
    }
  end

  def lock_plan_records!
    plan.lock_keys.each do |key|
      record_type, record_id = key.split(":", 2)
      record_type.constantize.unscoped.lock.find(record_id)
    end
  end

  def replan
    ReferenceMerges::ReallocationPlanner.new(
      user_card: plan.user_card,
      context: plan.context,
      source_date: plan.source_date,
      target_date: plan.target_date
    ).call
  end

  def apply_locked_plan!
    source_closing_date = source_reference.reference_closing_date

    @locked_plan.buckets.reverse_each do |bucket|
      move_bucket_installments!(bucket)
      move_bucket_exchanges!(bucket)
    end
    Audit::BulkMutation.update_columns!(target_reference, reference_closing_date: source_closing_date)
    source_reference.destroy!

    verify_final_graph!
    recalculate_balances!
  end

  def move_bucket_installments!(bucket)
    destination_reference = destination_reference_for(bucket.destination_date) if bucket.installment_ids.present?

    CardInstallment.unscoped.where(id: bucket.installment_ids).order(:id).each do |installment|
      installment.card_payment_reference_override = destination_reference
      installment.update!(
        month: bucket.destination_date.month,
        year: bucket.destination_date.year
      )
    end
  end

  def move_bucket_exchanges!(bucket)
    return if bucket.exchange_ids.empty?

    destination_reference = destination_reference_for(bucket.destination_date)

    Exchange.where(id: bucket.exchange_ids).order(:id).each do |exchange|
      exchange.update!(
        date: destination_reference.reference_date,
        month: bucket.destination_date.month,
        year: bucket.destination_date.year
      )
    end
  end

  def destination_reference_for(date)
    plan.user_card.references.find_by(context: plan.context, month: date.month, year: date.year) || create_destination_reference!(date)
  end

  def create_destination_reference!(date)
    reference_date = target_reference.reference_date.next_month(month_distance(plan.target_date, date))
    plan.user_card.references.create!(
      context: plan.context,
      month: date.month,
      year: date.year,
      reference_date:
    )
  end

  def month_distance(origin, destination)
    ((destination.year - origin.year) * 12) + destination.month - origin.month
  end

  def source_reference
    @source_reference ||= plan.user_card.references.find_by!(
      context: plan.context,
      month: plan.source_date.month,
      year: plan.source_date.year
    )
  end

  def target_reference
    @target_reference ||= plan.user_card.references.find_by!(
      context: plan.context,
      month: plan.target_date.month,
      year: plan.target_date.year
    )
  end

  def verify_final_graph!
    @locked_plan.buckets.each do |bucket|
      CardInstallment.unscoped.where(id: bucket.installment_ids).find_each do |installment|
        verify_installment!(installment, bucket.destination_date)
      end
      Exchange.where(id: bucket.exchange_ids).find_each { |exchange| verify_exchange!(exchange, bucket.destination_date) }
    end

    verify_source_removed!
  end

  def verify_source_removed!
    raise IntegrityError if plan.user_card.references.exists?(context: plan.context, month: plan.source_date.month, year: plan.source_date.year)
    raise IntegrityError if plan.user_card.unpaid_invoices(context: plan.context).exists?(month: plan.source_date.month, year: plan.source_date.year)
  end

  def verify_installment!(installment, expected_date)
    invoice = installment.cash_transaction
    valid = installment.month == expected_date.month &&
            installment.year == expected_date.year &&
            installment.date == original_attribute_for(installment, "date") &&
            invoice&.month == expected_date.month &&
            invoice&.year == expected_date.year &&
            invoice&.user_card_id == plan.user_card.id &&
            invoice&.context_id == plan.context.id
    raise IntegrityError unless valid
  end

  def original_attribute_for(record, attribute)
    planned_state = locked_plan_states.fetch([ record.class.base_class.name, record.id ])
    planned_state.fetch(:attributes).fetch(attribute)
  end

  def locked_plan_states
    @locked_plan_states ||= @locked_plan.state_rows.index_by { |row| [ row.fetch(:record_type), row.fetch(:record_id) ] }
  end

  def verify_exchange!(exchange, expected_date)
    reference = destination_reference_for(expected_date)
    projection = exchange.cash_transaction
    valid = exchange.month == expected_date.month &&
            exchange.year == expected_date.year &&
            exchange.date.to_date == reference.reference_date &&
            projection&.month == expected_date.month &&
            projection&.year == expected_date.year &&
            projection&.user_card_id == plan.user_card.id &&
            projection&.context_id == plan.context.id
    raise IntegrityError unless valid

    verify_projection_total!(projection)
  end

  def verify_projection_total!(projection)
    expected_price = Exchange.where(cash_transaction_id: projection.id).sum(:price)
    raise IntegrityError unless projection.price == expected_price
    raise IntegrityError unless projection.cash_installments.sole.price == expected_price
  end

  def recalculate_balances!
    Logic::RecalculateBalancesService.new(
      user: plan.user_card.user,
      context: plan.context,
      year: plan.source_date.year,
      month: plan.source_date.month
    ).call
  end

  def result(status, reason_code = nil, operation: nil)
    Result.new(status: status.to_s, reason_code: reason_code&.to_s, plan:, operation:)
  end

  def log_rejection(reason_code, error: nil, issues: nil)
    Rails.logger.warn(
      "reference_reallocation_rejected #{log_payload(reason_code:, error:, issues:).to_json}"
    )
  end

  def log_failure(error)
    Rails.logger.error(
      "reference_reallocation_failed #{log_payload(reason_code: :apply_failed, error:).to_json}"
    )
  end

  def log_payload(reason_code:, error: nil, issues: nil)
    {
      reason_code: reason_code.to_s,
      user_card_id: plan.user_card.id,
      context_id: plan.context.id,
      source_reference: plan.source_date&.iso8601,
      target_reference: plan.target_date&.iso8601,
      issues:,
      error_class: error&.class&.name,
      error_message: error&.message
    }.compact
  end
end
