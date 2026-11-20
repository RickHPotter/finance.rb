# frozen_string_literal: true

class PiggyBankReconciliations::Apply
  DEFAULT_DESCRIPTION = "OBSERVED NET RECONCILIATION"

  attr_reader :user, :context, :return_cash_transaction_id, :observed_net_cents,
              :observed_on, :installment_date, :digest, :description, :request_id

  def self.call(...)
    new(...).call
  end

  def self.from_plan(plan, digest: plan.digest, description: nil, request_id: nil)
    target = plan.return_cash_transaction
    new(
      user: target&.user,
      context: target&.context,
      return_cash_transaction_id: target&.id,
      observed_net_cents: plan.observed_net_cents,
      observed_on: plan.observed_on,
      installment_date: plan.installment_date,
      digest:,
      description:,
      request_id:
    )
  end

  def initialize(user:, context:, return_cash_transaction_id:, observed_net_cents:, observed_on:, digest:, description: nil, request_id: nil,
                 installment_date: nil)
    @user = user
    @context = context
    @return_cash_transaction_id = return_cash_transaction_id
    @observed_net_cents = observed_net_cents
    @observed_on = observed_on
    @installment_date = installment_date
    @digest = digest&.to_s
    @description = description
    @request_id = request_id
  end

  def call
    ApplicationRecord.transaction do
      return_transaction = find_and_lock_return_transaction

      plan = preview_for(return_transaction)
      return result(status: :invalid, reason_code: plan.reason_code, plan:, issues: plan.issues) if plan.invalid?
      return result(status: :stale, reason_code: :stale_preview, plan:) unless digest_matches?(plan)
      return result(status: :noop, plan:) if plan.noop?

      mutate_and_sync!(plan, return_transaction)
    end
  rescue ActiveRecord::RecordInvalid
    result(status: :failed, reason_code: :validation_failed)
  rescue ActiveRecord::ActiveRecordError
    result(status: :failed, reason_code: :apply_failed)
  rescue StandardError
    result(status: :failed, reason_code: :unexpected_failure)
  end

  private

  def find_and_lock_return_transaction
    return nil if context.blank? || user.blank? || return_cash_transaction_id.blank?

    context.cash_transactions
           .where(user:)
           .lock
           .find_by(id: return_cash_transaction_id)
  end

  def preview_for(return_transaction)
    PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: return_transaction&.id || return_cash_transaction_id,
      observed_net_cents:,
      observed_on:,
      installment_date:
    ).call
  end

  def digest_matches?(plan)
    digest.present? && ActiveSupport::SecurityUtils.secure_compare(digest, plan.digest.to_s)
  end

  def mutate_and_sync!(plan, return_transaction)
    target = plan.return_cash_transaction || return_transaction
    investment = nil
    operation = nil

    Audit::Operation.run(
      source: :web,
      join_existing: false,
      actor: user,
      context:,
      request_id:,
      metadata: operation_metadata(plan)
    ) do
      investment = build_investment(plan, target)
      investment.save!

      place_unpaid_installments(target, plan.installment_date)

      operation = Audit::Operation.ensure_persisted!
    end

    result(
      status: :applied,
      plan:,
      investment:,
      return_cash_transaction: target.reload,
      operation:
    )
  end

  # The piggy bank projection sync drags the unpaid installments back to the return
  # transaction date. Place them on the reconciled date instead, keeping the distance
  # between them, so the money lands on the date the user picked.
  def place_unpaid_installments(return_transaction, target_date)
    return if target_date.blank?

    installments = return_transaction.cash_installments.where(paid: false).order(:number).to_a
    return if installments.empty?

    shift = target_date - installments.first.date.to_date
    return if shift.zero?

    Audit::Operation.with_mutation_source(:piggy_bank_sync) do
      installments.each do |installment|
        moved_date = installment.date + shift.days
        installment.update!(date: moved_date, month: moved_date.month, year: moved_date.year)
      end
    end

    recalculate_balances(installments, target_date)
  end

  # The balance history depends on the installment dates, so it has to be rebuilt from the
  # earliest month the placement touched.
  def recalculate_balances(installments, target_date)
    months = (installments.map { |installment| installment.date.to_date } + [ target_date ]).map { |date| [ date.year, date.month ] }
    year, month = months.min
    Logic::RecalculateBalancesService.new(user:, context:, year:, month:).call
  end

  def build_investment(plan, target)
    Investment.new(
      user:,
      context:,
      user_bank_account: target.user_bank_account,
      investment_type_id: plan.investment_type_id,
      piggy_bank_return_cash_transaction: target,
      description: normalized_description,
      price: plan.delta_cents,
      date: plan.observed_on,
      month: plan.observed_on.month,
      year: plan.observed_on.year
    )
  end

  def operation_metadata(plan)
    {
      operation_kind: "piggy_bank_net_reconciliation",
      return_cash_transaction_id: plan.return_cash_transaction.id,
      context_id: context.id,
      user_id: user.id,
      observed_on: plan.observed_on.iso8601,
      installment_date: plan.installment_date&.iso8601,
      recorded_remaining_cents: plan.recorded_remaining_cents,
      observed_net_cents: plan.observed_net_cents,
      delta_cents: plan.delta_cents,
      preview_digest: plan.digest
    }
  end

  def normalized_description
    description&.strip.presence || default_description
  end

  def default_description
    I18n.t("piggy_bank_reconciliations.default_investment_description", default: DEFAULT_DESCRIPTION).upcase
  end

  def result(status:, reason_code: nil, plan: nil, investment: nil, return_cash_transaction: nil, operation: nil, issues: [])
    PiggyBankReconciliations::Result.new(
      status:,
      reason_code:,
      plan:,
      investment:,
      return_cash_transaction:,
      operation:,
      issues:
    )
  end
end
