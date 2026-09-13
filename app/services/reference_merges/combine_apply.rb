# frozen_string_literal: true

class ReferenceMerges::CombineApply
  class RejectedError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code
      super(reason_code.to_s)
    end
  end

  attr_reader :user_card, :context, :source_date, :target_date

  def initialize(user_card:, context:, source_date:, target_date:)
    @user_card = user_card
    @context = context
    @source_date = source_date
    @target_date = target_date
  end

  def call
    return ReferenceMerges::Result.rejected(:context_mismatch) unless context.user_id == user_card.user_id
    return ReferenceMerges::Result.rejected(:not_adjacent) unless adjacent?

    apply_inside_audit_operation
    ReferenceMerges::Result.applied(operation: @operation)
  rescue RejectedError => e
    ReferenceMerges::Result.rejected(e.reason_code)
  rescue ActiveRecord::ActiveRecordError => e
    log_failure(e)
    ReferenceMerges::Result.failed(:apply_failed)
  end

  private

  def adjacent?
    source_date.prev_month == target_date || source_date.next_month == target_date
  end

  def apply_inside_audit_operation
    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor: user_card.user,
      context:,
      metadata: operation_metadata
    ) do
      ApplicationRecord.transaction do
        ReferenceMerges::Lock.acquire!(user_card:, context:)
        load_and_lock_graph!
        apply_locked_graph!
        @operation = Audit::Operation.ensure_persisted!
      end
    end
  end

  def load_and_lock_graph!
    load_and_lock_references!
    load_and_lock_invoices!
    reject!(:combine_missing_root) unless @source_reference && @target_reference && @source_card_payment && @target_card_payment

    lock_invoice_graph!
    @source_exchanges = source_exchanges.lock.to_a
    lock_exchange_projections!
  end

  def load_and_lock_references!
    @references = rows_for_dates(user_card.references.where(context:)).order(:id).lock.to_a
    @source_reference = reference_for(source_date)
    @target_reference = reference_for(target_date)
  end

  def load_and_lock_invoices!
    invoice_ids = rows_for_dates(user_card.unpaid_invoices(context:)).ids
    invoices = CashTransaction.where(id: invoice_ids).order(:id).lock.to_a
    @source_card_payment = sole_row_for(invoices, source_date)
    @target_card_payment = sole_row_for(invoices, target_date)
  end

  def reference_for(date)
    @references.find { |reference| reference.year == date.year && reference.month == date.month }
  end

  def rows_for_dates(scope)
    scope.where(year: source_date.year, month: source_date.month)
         .or(scope.where(year: target_date.year, month: target_date.month))
  end

  def sole_row_for(rows, date)
    matching = rows.select { |row| row.year == date.year && row.month == date.month }
    matching.sole if matching.one?
  end

  def lock_invoice_graph!
    invoice_ids = [ @source_card_payment.id, @target_card_payment.id ]
    CashInstallment.where(cash_transaction_id: invoice_ids).order(:id).lock.load
    CardInstallment.unscoped.where(cash_transaction_id: invoice_ids).order(:id).lock.load
  end

  def source_exchanges
    Exchange
      .joins(:entity_transaction)
      .joins("INNER JOIN card_transactions ON card_transactions.id = entity_transactions.transactable_id " \
             "AND entity_transactions.transactable_type = 'CardTransaction'")
      .where(bound_type: :card_bound, month: source_date.month, year: source_date.year)
      .where(card_transactions: { user_card_id: user_card.id, context_id: context.id })
      .order(:id)
  end

  def lock_exchange_projections!
    projection_ids = @source_exchanges.filter_map(&:cash_transaction_id).uniq
    CashTransaction.where(id: projection_ids).order(:id).lock.load
    CashInstallment.where(cash_transaction_id: projection_ids).order(:id).lock.load
  end

  def apply_locked_graph!
    move_installments!
    move_exchanges!
    Audit::BulkMutation.update_columns!(@target_reference, reference_closing_date: @source_reference.reference_closing_date)
    @source_reference.destroy!

    min_date = [ source_date, target_date ].min
    Logic::RecalculateBalancesService.new(user: user_card.user, context:, year: min_date.year, month: min_date.month).call
  end

  def move_installments!
    Audit::BulkMutation.update_all!(
      @source_card_payment.card_installments,
      year: target_date.year,
      month: target_date.month,
      cash_transaction_id: @target_card_payment.id
    )

    new_target_price = @target_card_payment.card_installments.reload.sum(:price)
    new_target_comment = @target_card_payment.card_installments.first&.comment
    Audit::BulkMutation.update_columns!(@target_card_payment, price: new_target_price, comment: new_target_comment)
    Audit::BulkMutation.update_columns!(@target_card_payment.cash_installments.first, price: new_target_price) if @target_card_payment.cash_installments.any?
    @source_card_payment.reload.destroy!
  end

  def move_exchanges!
    @source_exchanges.each do |exchange|
      exchange.update!(month: target_date.month, year: target_date.year, date: @target_reference.reference_date)
    end
  end

  def operation_metadata
    affected_dates = [ source_date, target_date ].sort
    {
      reference_merge_mode: Logic::References::COMBINE_INTO_TARGET,
      user_card_id: user_card.id,
      context_id: context.id,
      source_reference: source_date.iso8601,
      target_reference: target_date.iso8601,
      earliest_affected_reference: affected_dates.first.iso8601,
      latest_affected_reference: affected_dates.last.iso8601,
      tail_reference: affected_dates.last.iso8601
    }
  end

  def reject!(reason_code)
    raise RejectedError, reason_code
  end

  def log_failure(error)
    Rails.logger.error(
      {
        event: "reference_combine_failed",
        reason_code: "apply_failed",
        user_card_id: user_card.id,
        context_id: context.id,
        source_reference: source_date.iso8601,
        target_reference: target_date.iso8601,
        error_class: error.class.name,
        error_message: error.message
      }.to_json
    )
  end
end
